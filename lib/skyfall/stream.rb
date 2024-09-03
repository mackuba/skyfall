require_relative 'messages/websocket_message'

require 'eventmachine'
require 'faye/websocket'
require 'uri'

module Skyfall
  class Stream
    SUBSCRIBE_REPOS = "com.atproto.sync.subscribeRepos"
    SUBSCRIBE_LABELS = "com.atproto.label.subscribeLabels"

    NAMED_ENDPOINTS = {
      :subscribe_repos => SUBSCRIBE_REPOS,
      :subscribe_labels => SUBSCRIBE_LABELS
    }

    EVENTS = %w(message raw_message connecting connect disconnect reconnect error timeout)

    MAX_RECONNECT_INTERVAL = 300

    attr_accessor :cursor, :auto_reconnect, :last_update, :user_agent
    attr_accessor :heartbeat_timeout, :heartbeat_interval, :check_heartbeat

    def initialize(server, endpoint, cursor = nil)
      @endpoint = check_endpoint(endpoint)
      @root_url = build_root_url(server)
      @cursor = check_cursor(cursor)
      @handlers = {}
      @auto_reconnect = true
      @check_heartbeat = false
      @connection_attempts = 0
      @heartbeat_interval = 10
      @heartbeat_timeout = 300
      @last_update = nil
      @user_agent = default_agent

      @handlers[:error] = proc { |e| puts "ERROR: #{e}" }
    end

    def connect
      return if @ws

      url = build_websocket_url

      @handlers[:connecting]&.call(url)
      @engines_on = true

      @reconnect_timer&.cancel
      @reconnect_timer = nil

      EM.run do
        EventMachine.error_handler do |e|
          @handlers[:error]&.call(e)
        end

        @ws = Faye::WebSocket::Client.new(url, nil, { headers: { 'User-Agent' => user_agent }})

        @ws.on(:open) do |e|
          @handlers[:connect]&.call
          @last_update = Time.now
          start_heartbeat_timer
        end

        @ws.on(:message) do |msg|
          @reconnecting = false
          @connection_attempts = 0
          @last_update = Time.now

          data = msg.data.pack('C*')
          @handlers[:raw_message]&.call(data)

          if @handlers[:message]
            atp_message = Skyfall::WebsocketMessage.new(data)
            @cursor = atp_message.seq
            @handlers[:message].call(atp_message)
          else
            @cursor = nil
          end
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

    def reconnect
      @reconnecting = true
      @connection_attempts = 0

      @ws ? @ws.close : connect
    end

    def disconnect
      return unless EM.reactor_running?

      @reconnecting = false
      @engines_on = false
      EM.stop_event_loop
    end

    alias close disconnect

    def default_agent
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

    EVENTS.each do |event|
      define_method "on_#{event}" do |&block|
        @handlers[event.to_sym] = block
      end

      define_method "on_#{event}=" do |block|
        @handlers[event.to_sym] = block
      end
    end

    def inspectable_variables
      instance_variables - [:@handlers, :@ws]
    end

    def inspect
      vars = inspectable_variables.map { |v| "#{v}=#{instance_variable_get(v).inspect}" }.join(", ")
      "#<#{self.class}:0x#{object_id} #{vars}>"
    end


    private

    def reconnect_delay
      if @connection_attempts == 0
        0
      else
        [2 ** (@connection_attempts - 1), MAX_RECONNECT_INTERVAL].min
      end
    end

    def build_websocket_url
      @root_url + "/xrpc/" + @endpoint + (@cursor ? "?cursor=#{@cursor}" : "")
    end

    def check_cursor(cursor)
      if cursor.nil?
        nil
      elsif cursor.is_a?(Integer) || cursor.is_a?(String) && cursor =~ /^[0-9]+$/
        cursor.to_i
      else
        raise ArgumentError, "Invalid cursor: #{cursor.inspect} - cursor must be an integer number"
      end
    end

    def check_endpoint(endpoint)
      if endpoint.is_a?(String)
        raise ArgumentError.new("Invalid endpoint name: #{endpoint}") if endpoint.strip == '' || !endpoint.include?('.')
      elsif endpoint.is_a?(Symbol)
        raise ArgumentError.new("Unknown endpoint: #{endpoint}") if NAMED_ENDPOINTS[endpoint].nil?
        endpoint = NAMED_ENDPOINTS[endpoint]
      else
        raise ArgumentError, "Endpoint should be a string or a symbol"
      end

      endpoint
    end

    def build_root_url(server)
      if server.is_a?(String)
        if server.start_with?('ws://') || server.start_with?('wss://')
          server
        elsif server.strip.empty? || server.include?('/')
          raise ArgumentError, "Server parameter should be a hostname or a ws:// or wss:// URL"
        else
          "wss://#{server}"
        end
      else
        raise ArgumentError, "Server parameter should be a string"
      end
    end
  end
end
