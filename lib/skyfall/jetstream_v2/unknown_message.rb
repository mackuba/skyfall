# frozen_string_literal: true

require_relative 'message'

module Skyfall

  #
  # Jetstream message of an unrecognized type.
  #

  class JetstreamV2::UnknownMessage < JetstreamV2::Message
  end
end
