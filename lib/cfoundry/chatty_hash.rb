module CFoundry
  class ChattyHash
    include Enumerable

    def initialize(callback, hash = {})
      @callback = callback
      @hash = hash
    end

    def [](name)
      @hash[name]
    end

    def []=(name, value)
      @hash[name] = value
      @callback.call(self)
      value
    end

    def each(&blk)
      @hash.each(&blk)
    end

    def delete(key)
      value = @hash.delete(key)
      @callback.call(self)
      value
    end

    def to_json(*args)
      @hash.to_json(*args)
    end

    def to_hash
      @hash
    end

    def to_s
      @hash.to_s
    end

    def inspect
      @hash.inspect
    end
  end
end
