# frozen_string_literal: true

module Skyfall

  # @private
  module Events
    protected

    def event_handler(name)
      define_method("on_#{name}") do |&block|
        @handlers[name.to_sym] = block
      end

      define_method("on_#{name}=") do |block|
        @handlers[name.to_sym] = block
      end
    end
  end
end
