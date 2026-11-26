# frozen_string_literal: true

unless ENV["GITHUB_ACTIONS"] == "true"
  require 'simplecov'

  SimpleCov.start do
    enable_coverage :branch
    formatter SimpleCov::Formatter::HTMLFormatter.new(silent: true)
  end
end

require 'cbor'
require 'skyfall'
require 'webmock/rspec'

if ENV['NATIVE_CBOR']
  require 'oxygene/cbor_native'
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.mock_with :mocha
end

WebMock.enable!

def sort_cbor_maps(obj)
  if obj.is_a?(Hash)
    obj.map { |k, v| [k, sort_cbor_maps(v)] }.sort_by { |k, v| [k.length, k] }.to_h
  elsif obj.is_a?(Array)
    obj.map { |x| sort_cbor_maps(x) }
  else
    obj
  end
end

def cbor_sequence(*objects)
  objects.map { |o| CBOR.encode(sort_cbor_maps(o)) }.join
end

TestWebsocketFrame = Struct.new(:data)

def websocket_frame(data)
  TestWebsocketFrame.new(data)
end
