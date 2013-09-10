# Zookeeper storage adapter for rollout

I've implemented a zookeeper-based storage adapter for [rollout][] that does 
not require any network roundtrips to check if a feature is active for a user.

It uses zookeeper watches to store the entire dataset in memory (which will 
generally be very small) and updates the local cache as soon as anything 
changes.

If you haven't migrated to rollout v2, you can just use this `:legacy_storage` 
option and things will migrate to redis. If you have alerady migrated, it 
would take some manual work (that I think could be fairly easy to automate).


## Usage

``` ruby
    $rollout = Rollout.new(
      Rollout::Zookeeper::Storage.new($zookeeper, "/rollout/users"),
      :legacy_storage => $redis, :migrate => true)
```

## Items of note

* it uses the [zk][] gem
* all settings are stored is a single znode
* this will automatically migrate everything properly if you haven't migrated to rollout v2 yet

[rollout]: https://github.com/jamesgolick/rollout
[zk]: https://github.com/slyphon/zk
[pull request]: https://github.com/jamesgolick/rollout/pull/31