# frozen_string_literal: true

require 'json'

shared_examples_for "invalid jetstream message" do
  context 'with invalid data' do
    it "should raise an error if 'kind' is missing" do
      data.delete('kind')

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, /kind/)
    end

    it "should raise an error if 'kind' is nil" do
      data['kind'] = nil

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, /kind/)
    end

    it "should raise an error if 'did' is missing" do
      data.delete('did')

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, /did/)
    end

    it "should raise an error if 'did' is nil" do
      data['did'] = nil

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, /did/)
    end

    it "should raise an error if 'time_us' is missing" do
      data.delete('time_us')

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, /time_us/)
    end

    it "should raise an error if 'time_us' is nil" do
      data['time_us'] = nil

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, /time_us/)
    end
  end
end
