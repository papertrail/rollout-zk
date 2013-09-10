require 'zk'
require 'yajl'

module Rollout::Zookeeper
  class DistributedHashtable
    def initialize(zk, path, options = {})
      @zk        = zk
      @path      = path
      @mutex     = Mutex.new
      @callbacks = []
      @on_error  = options[:on_error] || proc { |ex| }

      configure_watches
    end

    def on_change(&block)
      @mutex.synchronize do
        @callbacks << block
      end

      block.call
    end

    def fire
      callbacks = @mutex.synchronize do
        @callbacks.dup
      end

      callbacks.each do |cb|
        begin
          cb.call
        rescue => e
          @on_error.call(e)
        end
      end
    end

    def [](key)
      @mutex.synchronize do
        if @hashtable
          return @hashtable[key]
        end
      end
    end
    
    def []=(key, value)
      result = @mutex.synchronize do
        update do |hashtable|
          hashtable[key] = value
        end
      end

      fire

      return result
    end
    
    def has_key?(key)
      @mutex.synchronize do
        if @hashtable
          @hashtable.has_key?(key)
        end
      end
    end
    
    def delete(key)
      result = @mutex.synchronize do
        update do |hashtable|
          hashtable.delete(key)
        end
      end

      fire

      return result
    end

    def merge(other)
      result = @mutex.synchronize do
        update do |hashtable|
          hashtable.merge(other)
        end
      end

      fire

      return result
    end

    def to_h
      @mutex.synchronize do
        if @hashtable
          @hashtable.dup
        else
          {}
        end
      end
    end

    def each(&block)
      to_h.each(&block)
    end

    def length
      @mutex.synchronize do
        if @hashtable
          @hashtable.length
        else
          0
        end
      end
    end

    def empty?
      length == 0
    end
    alias_method :blank?, :empty?

    def read
      @mutex.synchronize do
        begin
          current, _ = @zk.get(@path, :watch => true)
          @hashtable = Yajl::Parser.parse(current)
        rescue ::ZK::Exceptions::NoNode
          if @zk.exists?(@path, :watch => true)
            retry
          else
            @hashtable = Hash.new
          end
        end
      end

      fire
    end

    def update(&block)
      return update_exists(&block)
    rescue ::ZK::Exceptions::NoNode
      begin
        return update_initial(&block)
      rescue ::ZK::Exceptions::NodeExists
        return update_exists(&block)
      end
    end

    def update_exists(&block)
      begin
        current, stat = @zk.get(@path, :watch => true)
        hashtable = Yajl::Parser.parse(current)

        result = block.call(hashtable)

        @zk.set(@path, Yajl::Encoder.encode(hashtable), :version => stat.version)
        @hashtable = hashtable

        return result
      rescue ::ZK::Exceptions::BadVersion
        sleep 0.1 + rand
        retry
      end
    end

    def update_initial(&block)
      begin
        hashtable = Hash.new

        result = block.call(hashtable)

        @zk.create(@path, Yajl::Encoder.encode(hashtable))
        @hashtable = hashtable

        return result
      rescue ::ZK::Exceptions::NoNode
        @zk.mkdir_p(File.dirname(@path))
        retry
      end
    end

    def configure_watches
      @register ||= @zk.register(@path) do
        read
      end

      @on_connected ||= @zk.on_connected do
        read
      end

      begin
        read
      rescue ::ZK::Exceptions::OperationTimeOut, ::Zookeeper::Exceptions::ContinuationTimeoutError, ::Zookeeper::Exceptions::NotConnected => e
        # Ignore these, we'll get them next time

        @on_error.call(e)
      end
    end
  end
end