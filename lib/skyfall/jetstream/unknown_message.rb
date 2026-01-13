# frozen_string_literal: true

require_relative '../jetstream'
require_relative 'message'

module Skyfall

  #
  # Jetstream message of an unrecognized type.
  #

  class Jetstream::UnknownMessage < Jetstream::Message
  end
end
