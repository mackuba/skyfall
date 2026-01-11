require 'eventmachine'
require 'faye/websocket'
require 'uri'

require_relative 'events'
require_relative 'version'

module Skyfall

  # Base class of a websocket client. It provides basic websocket client functionality such as
  # connecting to the service, keeping the connection alive and running lifecycle callbacks.
  #
  # In most cases, you will not create instances of this class directly, but rather use either
  # {Firehose} or {Jetstream}. Use this class as a superclass if you need to implement some
  # custom client for a websocket API that isn't supported yet.

  class Stream
    extend Events

    MAX_RECONNECT_INTERVAL = 300

    # If enabled, the client will try to reconnect if the connection is closed unexpectedly.
    # (Default: true)
    #
    # When the reconnect attempt fails, it will wait with an exponential backoff delay before
    # retrying again, up to {MAX_RECONNECT_INTERVAL} seconds.
    #
    # @return [Boolean]
    attr_accessor :auto_reconnect

    # User agent sent in the header when connecting.
    #
    # Default value is {#default_user_agent} = {#version_string} `(Skyfall/x.y)`. It's recommended
    # to set it or extend it with some information that indicates what service this is and who is
    # running it (e.g. a Bluesky handle).
    #
    # @return [String]
    # @example
    #   client.user_agent = "my.service (@my.handle) #{client.version_string}"
    attr_accessor :user_agent

    # If enabled, runs a timer which does periodical "heatbeat checks".
    #
    # The heartbeat timer is started when the client connects to the service, and checks if the stream
    # hasn't stalled and is still regularly sending new messages. If no messages are detected for some
    # period of time, the client forces a reconnect.
    #
    # This is **not** enabled by default, because depending on the service you're connecting to, it
    # might be normal to not receive any messages for a while.
    #
    # @see #heartbeat_timeout
    # @see #heartbeat_interval
    # @return [Boolean]
    attr_accessor :check_heartbeat

    # Interval in seconds between heartbeat checks (default: 10). Only used if {#check_heartbeat} is set.
    # @return [Numeric]
    attr_accessor :heartbeat_interval

    # Number of seconds without messages after which reconnect is triggered (default: 300).
    # Only used if {#check_heartbeat} is set.
    # @return [Numeric]
    attr_accessor :heartbeat_timeout

    # Time when the most recent message was received from the websocket.
    #
    # Note: this is _local time_ when the message was received; this is different from the timestamp
    # of the message, which is the server time of the original source (PDS) when emitting the message,
    # and different from a potential `created_at` saved in the record.
    #
    # @return [Time, nil]
    attr_reader :last_update

    #
    # @param server [String] Address of the server to connect to.
    #   Expects a string with either just a hostname, or a ws:// or wss:// URL.
    #
    # @raise [ArgumentError] if the server parameter is invalid
    #
    def initialize(server)
      @root_url = build_root_url(server)

      @handlers = {}
      @auto_reconnect = true
      @check_heartbeat = false
      @connection_attempts = 0
      @heartbeat_interval = 10
      @heartbeat_timeout = 300
      @last_update = nil
      @user_agent = default_user_agent

      @handlers[:error] = proc { |e| puts "ERROR: #{e}" }
    end

    #
    # Opens a connection to the configured websocket.
    #
    # This method starts an EventMachine reactor on the current thread, and will only return
    # once the connection is closed.
    #
    # @return [nil]
    # @raise [ReactorActiveError] if another stream is already running
    #
    def connect
      return if @ws

      url = build_websocket_url

      @handlers[:connecting]&.call(url)

      @reconnect_timer&.cancel
      @reconnect_timer = nil

      raise ReactorActiveError if existing_reactor?

      @engines_on = true

      EM.run do
        EventMachine.error_handler do |e|
          @handlers[:error]&.call(e)
        end

        @ws = build_websocket_client(url)

        @ws.on(:open) do |e|
          @handlers[:connect]&.call
          @last_update = Time.now
          start_heartbeat_timer
        end

        @ws.on(:message) do |msg|
          @reconnecting = false
          @connection_attempts = 0
          @last_update = Time.now
          handle_message(msg)
        end

        @ws.on(:error) do |e|
          @handlers[:error]&.call(e)
        end

        @ws.on(:close) do |e|
          @ws = nil

          if @reconnecting || @auto_reconnect && @engines_on
            @handlers[:reconnect]&.call

            @reconnect_timer&.cancel
            @reconnect_timer = EM::Timer.new(reconnect_delay) do
              @connection_attempts += 1
              connect
            end
          else
            stop_heartbeat_timer
            @engines_on = false
            @handlers[:disconnect]&.call
            EM.stop_event_loop unless @ws
          end
        end
      end
    end

    #
    # Forces a reconnect, closing the connection and calling {#connect} again.
    # @return [nil]
    #
    def reconnect
      @reconnecting = true
      @connection_attempts = 0

      @ws ? @ws.close : connect
    end

    #
    # Closes the connection and stops the EventMachine reactor thread.
    # @return [nil]
    #
    def disconnect
      return unless EM.reactor_running?

      @reconnecting = false
      @engines_on = false
      EM.stop_event_loop
    end

    alias close disconnect

    #
    # Default user agent sent when connecting to the service. (Currently `"#{version_string}"`)
    # @return [String]
    #
    def default_user_agent
      version_string
    end

    #
    # Skyfall version string for use in user agent strings (`"Skyfall/x.y"`).
    # @return [String]
    #
    def version_string
      "Skyfall/#{Skyfall::VERSION}"
    end

    def check_heartbeat=(value)
      @check_heartbeat = value

      if @check_heartbeat && @engines_on && @ws && !@heartbeat_timer
        start_heartbeat_timer
      elsif !@check_heartbeat && @heartbeat_timer
        stop_heartbeat_timer
      end
    end


    # @!method on_connecting(block)
    #   Defines a callback to be run when the client tries to open a connection to the websocket.
    #   Can be also run as a setter `on_connecting=`.
    #   @param [Proc] block
    #   @yieldparam [String] url URL to which the client is connecting
    #   @return [nil]

    event_handler :connecting

    # @!method on_connect(block)
    #   Defines a callback to be run after a connection to the websocket is opened.
    #   Can be also run as a setter `on_connect=`.
    #   @param [Proc] block
    #   @return [nil]

    event_handler :connect

    # @!method on_raw_message(block)
    #   Defines a callback to be run when a message is received, passing a raw data packet as
    #   received from the websocket (plain text or binary). Can be also run as a setter `on_raw_message=`.
    #   @param [Proc] block
    #   @yieldparam [String] data payload of the received message
    #   @return [nil]

    event_handler :raw_message

    # @!method on_message(block)
    #   Defines a callback to be run when a message is received, passing the message as a parsed
    #   object of an appropriate message class. Can be also run as a setter `on_message=`.
    #   @param [Proc] block
    #   @yieldparam [Object] message parsed message of an appropriate class
    #   @return [nil]

    event_handler :message

    # @!method on_disconnect(block)
    #   Defines a callback to be run after a connection to the websocket is closed (and the client
    #   does not reconnect). Can be also run as a setter `on_disconnect=`.
    #
    #   This callback is not run when `on_reconnect` fires.
    #   @param [Proc] block
    #   @return [nil]

    event_handler :disconnect

    # @!method on_reconnect(block)
    #   Defines a callback to be run when a connection to the websocket is broken, but the client
    #   initiates or schedules a reconnect (which may happen after a delay). Can be also run as
    #   a setter `on_reconnect=`.
    #   @param [Proc] block
    #   @return [nil]

    event_handler :reconnect

    # @!method on_timeout(block)
    #   Defines a callback to be run when the heartbeat timer forces a reconnect. A reconnect is
    #   triggered after not receiving any messages for a period of time specified in {#heartbeat_timeout}
    #   (if {#check_heartbeat} is enabled). Can be also run as a setter `on_timeout=`.
    #
    #   This callback is also followed by `on_reconnect`.
    #   @param [Proc] block
    #   @return [nil]

    event_handler :timeout

    # @!method on_error(block)
    #   Defines a callback to be run when the websocket connection returns an error. Can be also
    #   run as a setter `on_error=`.
    #
    #   Default handler prints the error to stdout.
    #
    #   @param [Proc] block
    #   @yieldparam [Exception] error the received error
    #   @return [nil]

    event_handler :error


    # Returns a string with a representation of the object for debugging purposes.
    # @return [String]
    def inspect
      vars = inspectable_variables.map { |v| "#{v}=#{instance_variable_get(v).inspect}" }.join(", ")
      "#<#{self.class}:0x#{object_id} #{vars}>"
    end


    protected

    # @note This method is designed to be overridden in subclasses.
    #
    # Returns the full URL of the websocket endpoint to connect to, with path and query parameters
    # if needed. The base implementation simply returns the base URL passed to the initializer.
    #
    # Override this method in subclasses to point to the specific endpoint and add necessary
    # parameters like cursor or filters, depending on the arguments passed to the constructor.
    #
    # @return [String]

    def build_websocket_url
      @root_url
    end

    # Builds and configures a websocket client object that is used to connect to the requested service.
    #
    # @return [Faye::WebSocket::Client]
    #   see {https://rubydoc.info/gems/faye-websocket/Faye/WebSocket/Client Faye::WebSocket::Client}

    def build_websocket_client(url)
      Faye::WebSocket::Client.new(url, nil, { headers: { 'User-Agent' => user_agent }.merge(request_headers) })
    end

    # @note This method is designed to be overridden in subclasses.
    #
    # Processes a single message received from the websocket. The implementation is expected to
    # parse the message from a plain text or binary form, build an appropriate message object,
    # and call the `:message` and/or `:raw_message` callback handlers, passing the right parameters.
    #
    # The base implementation simply takes the message data and passes it as is to `:raw_message`,
    # and does not call `:message` at all.
    #
    # @param msg
    #   {https://rubydoc.info/gems/faye-websocket/Faye/WebSocket/API/MessageEvent Faye::WebSocket::API::MessageEvent}
    # @return [nil]

    def handle_message(msg)
      data = msg.data
      @handlers[:raw_message]&.call(data)
    end

    # Additional headers to pass with the request when connecting to the websocket endpoint.
    # The user agent header (built from {#user_agent}) is added separately.
    #
    # The base implementation returns an empty hash.
    #
    # @return [Hash] a hash of `{ header_name => header_value }`

    def request_headers
      {}
    end

    # Returns the underlying websocket client object. It can be used e.g. to send messages back
    # to the server (but see also: {#send_data}).
    #
    # @return [Faye::WebSocket::Client]
    #   see {https://rubydoc.info/gems/faye-websocket/Faye/WebSocket/Client Faye::WebSocket::Client}

    def socket
      @ws
    end

    # Sends a message back to the server.
    #
    # @param data [String, Array] the message to send -
    #   a string for text websockets, a binary string or byte array for binary websockets
    # @return [Boolean] true if the message was sent successfully

    def send_data(data)
      @ws.send(data)
    end

    # @return [Array<Symbol>] list of instance variables to be printed in the {#inspect} output
    def inspectable_variables
      instance_variables - [:@handlers, :@ws]
    end


    private

    def existing_reactor?
      EM.reactor_running? && !@engines_on
    end

    def start_heartbeat_timer
      return if !@check_heartbeat || @heartbeat_interval.to_f <= 0 || @heartbeat_timeout.to_f <= 0
      return if @heartbeat_timer

      @heartbeat_timer = EM::PeriodicTimer.new(@heartbeat_interval) do
        next if @ws.nil? || @heartbeat_timeout.to_f <= 0
        time_passed = Time.now - @last_update

        if time_passed > @heartbeat_timeout
          @handlers[:timeout]&.call
          reconnect
        end
      end
    end

    def stop_heartbeat_timer
      @heartbeat_timer&.cancel
      @heartbeat_timer = nil
    end

    def reconnect_delay
      if @connection_attempts == 0
        0
      else
        [2 ** (@connection_attempts - 1), MAX_RECONNECT_INTERVAL].min
      end
    end

    def build_root_url(server)
      if !server.is_a?(String)
        raise ArgumentError, "Server parameter should be a string"
      end

      if server.include?('://')
        uri = URI(server)

        if uri.scheme != 'ws' && uri.scheme != 'wss'
          raise ArgumentError, "Server parameter should be a hostname or a ws:// or wss:// URL"
        end

        uri.to_s
      else
        server = "wss://#{server}"
        uri = URI(server) # raises if invalid
        server
      end
    end

    def ensure_empty_path(url)
      url = url.chomp('/')

      if URI(url).path != ''
        raise ArgumentError, "Server URL should only include a hostname, without any path"
      end

      url
    end
  end
end
