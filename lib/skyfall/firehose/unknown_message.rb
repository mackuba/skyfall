require_relative '../firehose'

module Skyfall

  #
  # Firehose message of an unrecognized type.
  #

  class Firehose::UnknownMessage < Firehose::Message
  end
end
