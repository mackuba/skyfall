require_relative '../jetstream'

module Skyfall

  #
  # Jetstream message of an unrecognized type.
  #

  class Jetstream::UnknownMessage < Jetstream::Message
  end
end
