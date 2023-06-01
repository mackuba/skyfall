# frozen_string_literal: true

require_relative "lib/skyfall/version"

Gem::Specification.new do |spec|
  spec.name = "skyfall"
  spec.version = Skyfall::VERSION
  spec.authors = ["Kuba Suder"]
  spec.email = ["jakub.suder@gmail.com"]

  spec.summary = "A Ruby gem for streaming data from the Bluesky/AtProto firehose"
  spec.homepage = "https://github.com/mackuba/skyfall"

  # spec.description = "TODO: Write a longer description or delete this line."

  spec.license = "Zlib"
  spec.required_ruby_version = ">= 2.6.0"

  # spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.files = Dir.chdir(__dir__) do
    Dir['*.md'] + Dir['*.txt'] + Dir['lib/**/*'] + Dir['sig/**/*']
  end

  spec.require_paths = ["lib"]

  spec.add_dependency 'base32', '~> 0.3', '>= 0.3.4'
  spec.add_dependency 'cbor', '~> 0.5', '>= 0.5.9.6'
  spec.add_dependency 'websocket-client-simple', '~> 0.6', '>= 0.6.1'
end
