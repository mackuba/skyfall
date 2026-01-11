require_relative '../firehose'
require_relative 'message'

module Skyfall

  #
  # Firehose message of an unrecognized type.
  #

  class Firehose::UnknownMessage < Firehose::Message
  end
end
