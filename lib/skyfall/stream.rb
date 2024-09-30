require 'eventmachine'
require 'faye/websocket'
require 'uri'

module Skyfall
  class Stream
    EVENTS = %w(message raw_message connecting connect disconnect reconnect error timeout)
    MAX_RECONNECT_INTERVAL = 300

    attr_accessor :auto_reconnect, :last_update, :user_agent
    attr_accessor :heartbeat_timeout, :heartbeat_interval, :check_heartbeat

    def self.new(server, endpoint = nil, cursor = nil)
      # to be removed in 0.6
      if endpoint || cursor
        STDERR.puts "Warning: Skyfall::Stream has been renamed to Skyfall::Firehose. This initializer will be removed in the next version."
        Firehose.new(server, endpoint, cursor)
      else
        instance = self.allocate
        instance.send(:initialize, server)
        instance
      end
    end

    def initialize(service)
      @root_url = build_root_url(service)

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

    def handle_message(msg)
      data = msg.data
      @handlers[:raw_message]&.call(data)
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

    def default_user_agent
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
      @root_url
    end

    def build_root_url(service)
      if service.is_a?(String)
        if service.include?('/')
          uri = URI(service)
          if uri.scheme != 'ws' && uri.scheme != 'wss'
            raise ArgumentError, "Service parameter should be a hostname or a ws:// or wss:// URL"
          end
          uri.to_s
        else
          service = "wss://#{service}"
          uri = URI(service) # raises if invalid
          service
        end
      else
        raise ArgumentError, "Service parameter should be a string"
      end
    end
  end
end
