# frozen_string_literal: true

describe Skyfall::Firehose do
  it 'should build a websocket URL from hostname and endpoint' do
    firehose = Skyfall::Firehose.new('bsky.relay', 'com.atproto.sync.subscribeSomething')

    firehose.send(:build_websocket_url).should == 'wss://bsky.relay/xrpc/com.atproto.sync.subscribeSomething'
    firehose.cursor.should be_nil
  end

  it 'should accept a cursor' do
    firehose = Skyfall::Firehose.new('bsky.relay', 'com.atproto.sync.subscribeRecords', 1234)

    firehose.send(:build_websocket_url).should == 'wss://bsky.relay/xrpc/com.atproto.sync.subscribeRecords?cursor=1234'
    firehose.cursor.should == 1234
  end

  context 'with a symbolic endpoint name' do
    it 'should accept known endpoints' do
      firehose = Skyfall::Firehose.new('bsky.relay', :subscribe_labels)

      firehose.send(:build_websocket_url).should == 'wss://bsky.relay/xrpc/com.atproto.label.subscribeLabels'
    end

    it 'should accept known endpoints with a cursor' do
      firehose = Skyfall::Firehose.new('bsky.relay', :subscribe_repos, 2048)

      firehose.send(:build_websocket_url).should == 'wss://bsky.relay/xrpc/com.atproto.sync.subscribeRepos?cursor=2048'
    end

    it 'should raise ArgumentError for unknown endpoints' do
      expect { Skyfall::Firehose.new('bsky.relay', :foobar) }.to raise_error(ArgumentError)
    end
  end

  context 'if cursor is an explicit nil' do
    it 'should not raise an error' do
      firehose = Skyfall::Firehose.new('bsky.relay', :subscribe_repos, nil)

      firehose.send(:build_websocket_url).should == 'wss://bsky.relay/xrpc/com.atproto.sync.subscribeRepos'
      firehose.cursor.should be_nil
    end
  end

  context 'if cursor is a numeric string' do
    it 'should cast it to integer' do
      firehose = Skyfall::Firehose.new('bsky.relay', :subscribe_repos, '202122')

      firehose.send(:build_websocket_url).should == 'wss://bsky.relay/xrpc/com.atproto.sync.subscribeRepos?cursor=202122'
      firehose.cursor.should == 202122
    end
  end

  context 'if endpoint parameter is skipped' do
    it 'should default to subscribeRepos' do
      firehose = Skyfall::Firehose.new('bsky.relay')

      firehose.send(:build_websocket_url).should == 'wss://bsky.relay/xrpc/com.atproto.sync.subscribeRepos'
    end

    it 'should accept a cursor as the second argument' do
      firehose = Skyfall::Firehose.new('bsky.relay', 6000)

      firehose.cursor.should == 6000
      firehose.send(:build_websocket_url).should == 'wss://bsky.relay/xrpc/com.atproto.sync.subscribeRepos?cursor=6000'
    end

    it 'should accept a cursor as string in the second argument' do
      firehose = Skyfall::Firehose.new('bsky.relay', '555')

      firehose.cursor.should == 555
      firehose.send(:build_websocket_url).should == 'wss://bsky.relay/xrpc/com.atproto.sync.subscribeRepos?cursor=555'
    end
  end

  context 'if cursor is not valid' do
    it 'should raise an ArgumentError' do
      cursors = [
        [1, 2],
        { 'endpoint' => :subscribe_repos },
        'lizard'
      ]

      cursors.each do |c|
        expect { Skyfall::Firehose.new('bsky.relay', :subscribe_repos, c) }.to raise_error(ArgumentError)
      end
    end
  end

  context 'if endpoint is not valid' do
    it 'should raise an ArgumentError' do
      endpoints = [
        [3, 4],
        { 'endpoint' => :subscribe_repos },
        'lizard',
        '   '
      ]

      endpoints.each do |e|
        expect { Skyfall::Firehose.new('bsky.relay', e) }.to raise_error(ArgumentError)
      end
    end
  end

  context 'if the server argument is a URL' do
    it 'should allow a URL with no path' do
      firehose = Skyfall::Firehose.new('ws://localhost:3000')
      firehose.send(:build_websocket_url).should == 'ws://localhost:3000/xrpc/com.atproto.sync.subscribeRepos'
    end

    it 'should reject a URL with some path' do
      expect { Skyfall::Firehose.new('ws://localhost:3000/test/') }.to raise_error(ArgumentError)
    end
  end
end
