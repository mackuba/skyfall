module Skyfall
  class Operation
    attr_reader :repo, :path, :action, :cid, :record

    def initialize(repo, path, action, cid, record)
      @repo = repo
      @path = path
      @action = action
      @cid = cid
      @record = record
    end

    def uri
      "at://#{repo}/#{path}"
    end

    def collection
      path.split('/').first
    end
  end
end
