describe Skyfall::Collection do
  subject { Skyfall::Collection }

  describe '.short_code' do
    it 'should map known collection names to short codes' do
      subject.short_code(subject::BSKY_POST).should == :bsky_post
    end

    it 'should return :unknown for unknown collections' do
      subject.short_code('app.bsky.unknown').should == :unknown
    end
  end

  describe '.from_short_code' do
    it 'should map short codes back to collection names' do
      subject.from_short_code(:bsky_like).should == subject::BSKY_LIKE
    end

    it 'should return nil for unknown short codes' do
      subject.from_short_code(:leaflet_post).should be_nil
    end
  end
end
