# frozen_string_literal: true

describe Skyfall::Label do
  let(:cid) { 'bafyreicamyy23i3aglu35qy5lmretkdgrovvvtvo6yi62onfrx2wyqkqoi' }

  let(:data) {{
    'ver' => 1,
    'src' => "did:web:labeller.example.com",
    'uri' => "at://did:web:atproto.com/app.bsky.feed.post/123",
    'cid' => cid,
    'val' => "test",
    'cts' => "2024-01-01T00:00:00Z",
    'exp' => "2025-01-01T00:00:00Z",
    'neg' => true
  }}

  subject(:label) { described_class.new(data) }

  context "with valid data" do
    it "should expose the original data" do
      label.data.should equal(data)
    end

    it "should parse the label fields" do
      label.version.should == 1
      label.authority.should == "did:web:labeller.example.com"
      label.subject.should == "at://did:web:atproto.com/app.bsky.feed.post/123"
      label.value.should == "test"
      label.should be_a_negation
    end

    it "should parse the CID" do
      label.cid.should be_a(Oxygene::CID)
      label.cid.to_s.should == cid
    end

    it "should parse the timestamps" do
      label.created_at.should == Time.parse("2024-01-01T00:00:00Z")
      label.expires_at.should == Time.parse("2025-01-01T00:00:00Z")
    end

    it "should expose short aliases" do
      label.ver.should == label.version
      label.src.should == label.authority
      label.uri.should == label.subject
      label.val.should == label.value
      label.neg.should == label.negation?
      label.cts.should == label.created_at
      label.exp.should == label.expires_at
    end

    it "should accept a DID as the subject" do
      data['uri'] = "did:web:foo.com"

      label.subject.should == "did:web:foo.com"
    end
  end

  context "without optional fields" do
    before do
      data.delete('cid')
      data.delete('exp')
      data.delete('neg')
    end

    it "should return nil for the CID" do
      label.cid.should be_nil
    end

    it "should return nil for the expiry timestamp" do
      label.expires_at.should be_nil
    end

    it "should not be a negation" do
      label.should_not be_a_negation
    end
  end

  describe "version validation" do
    it "should raise an error when the version is missing" do
      data.delete('ver')

      expect { label }.to raise_error(Skyfall::DecodeError, /Missing version/)
    end

    { 'nil' => nil, 'a string' => '1', '0' => 0, 'negative' => -1 }.each do |desc, value|
      it "should raise an error when the version is #{desc}" do
        data['ver'] = value

        expect { label }.to raise_error(Skyfall::DecodeError, /Invalid version/)
      end
    end

    it "should raise on an unknown future version" do
      data['ver'] = 2

      expect { label }.to raise_error(Skyfall::UnsupportedError, /Unsupported version/)
    end
  end

  describe "source validation" do
    it "should raise when the source is missing" do
      data.delete('src')

      expect { label }.to raise_error(Skyfall::DecodeError, /Missing source/)
    end

    { 'nil' => nil, 'not a string' => 123, 'not a valid did' => "alice.test" }.each do |desc, value|
      it "should raise when the source is #{desc}" do
        data['src'] = value

        expect { label }.to raise_error(Skyfall::DecodeError, /Invalid source/)
      end
    end
  end

  describe "subject validation" do
    it "should raise when the URI is missing" do
      data.delete('uri')

      expect { label }.to raise_error(Skyfall::DecodeError, /Missing uri/)
    end

    { 'nil' => nil, 'not a string' => 123, 'not an URI or DID' => "https://example.com/post/123" }.each do |desc, value|
      it "should raise when the URI is #{desc}" do
        data['uri'] = value

        expect { label }.to raise_error(Skyfall::DecodeError, /Invalid uri/)
      end
    end
  end
end
