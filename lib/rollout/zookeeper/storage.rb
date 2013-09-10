require 'rollout/zookeeper/distributed_hashtable'

module Rollout::Zookeeper
  class Storage
    def initialize(zk, path, options = {})
      @cache = ::Rollout::Zookeeper::DistributedHashtable.new(zk, path, options)
    end
  
    def get(key)
      @cache[key]
    end
  
    def set(key, value)
      @cache[key] = value.to_s
    end
  end
end