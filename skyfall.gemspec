# frozen_string_literal: true

require_relative "lib/skyfall/version"

Gem::Specification.new do |spec|
  spec.name = "skyfall"
  spec.version = Skyfall::VERSION
  spec.authors = ["Kuba Suder"]
  spec.email = ["jakub.suder@gmail.com"]

  spec.summary = "A Ruby gem for streaming data from the Bluesky/AtProto firehose"
  spec.homepage = "https://github.com/mackuba/skyfall"

  spec.description = %(
    Skyfall is a Ruby library for connecting to the "firehose" of the Bluesky social network, i.e. a websocket which
    streams all new posts and everything else happening on the Bluesky network in real time. The code connects to the
    websocket endpoint, decodes the messages which are encoded in some binary formats, and returns the data as Ruby
    objects, which you can filter and save to some kind of database (e.g. in order to create a custom feed).
  )

  spec.license = "Zlib"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata = {
    "bug_tracker_uri"   => "https://github.com/mackuba/skyfall/issues",
    "changelog_uri"     => "https://github.com/mackuba/skyfall/blob/master/CHANGELOG.md",
    "source_code_uri"   => "https://github.com/mackuba/skyfall",
  }

  spec.files = Dir.chdir(__dir__) do
    Dir['*.md'] + Dir['*.txt'] + Dir['example/**/*'] + Dir['lib/**/*'] + Dir['sig/**/*']
  end

  spec.require_paths = ["lib"]

  spec.add_dependency 'base32', '~> 0.3', '>= 0.3.4'
  spec.add_dependency 'base64', '~> 0.1'
  spec.add_dependency 'cbor', '~> 0.5', '>= 0.5.9.6'
  spec.add_dependency 'eventmachine', '~> 1.2', '>= 1.2.7'
  spec.add_dependency 'faye-websocket', '~> 0.11'
end
