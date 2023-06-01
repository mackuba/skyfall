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

  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  # spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end

  spec.require_paths = ["lib"]

  spec.add_dependency 'cbor', '>= 0.5.9.6'
  spec.add_dependency 'base32', '>= 0.3.4'
end
