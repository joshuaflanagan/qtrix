# Qtrix

Qtrix is a means by which to intelligently pick prioritized queues for background workers.  It supports the following:

* The concept of a global worker pool by which we can specifically configure individual workers across any number of servers.
* Queue prioritization based on queue weightings.
* Intelligent generation of queue lists for each worker in the global pool.
 * Every queue will be at the head of the list of at least one worker.
 * Queues with a higher priority will appear higher in the list of queues across the global worker pool than queues with a lower priority.
* Real time tweaking of queue prioritization that is propagated across the global worker pool without further effort.
* Overrides to specifically call out any number of workers to process a user-specified list of queues.
* Multiple configuration sets that can be switched to on-the-fly to handle shifting requirements of the global worker pool (day, night, weekend, etc...).  As above, this is propagated across the global worker pool without further effort.
* CLI to allow for scriptability of changes in queue prioritization or configuration sets.
* Easy API to allow for other interfaces to be developed.

## CLI
The CLI is provided by the ```qtrix``` executable.  It provides several sub-commands to perform different operations within qtrix as follows:

* **config_sets**:  Interact with configuration sets.
* **queues**:  Interact with queues within a configuration set.
* **overrides**: Interact with the overrides within a configuration set.

Using this, you can manipulate the global worker pool's resources so that they are directed to handle any scenario in real time.  It can be run manually on any machine that can establish a connection to the redis instance backing the global worker pool configuration.  It can be scripted via cron or other means to react to changing queue prioritization/resource needs.

### Common Options
The following options are common to all/most commands:

|option|description|
|------|-----------|
|--help|View help information about the command|
|-c    |Direct the operation to a specific configuration set|
|-h    |The redis host to connect to|
|-p    |The redis port to connect to|
|-n    |The redis database number to operate on|

### Interacting with Configuration Sets
To see all configuration sets:

```bash
bundle exec qtrix config_sets -l
```

To see the current configuration set:
```bash
bundle exec qtrix config_sets -c
```

To add a configuration set:
```bash
bundle exec qtrix config_sets --create night
```

To remove a configuration set:
```bash
bundle exec qtrix config_sets -d night
```

### Viewing or Specifying Queue Priority
To view the current queue priority:

```bash
bundle exec qtrix queues -l
```

To specify the current queue weightings by inline string:

```bash
bundle exec qtrix queues -w A:40,B:30,C:20,D:10
```

To specify the current queue weightings by an evaluated yaml file:

```bash
bundle exec qtrix queues -y ~/my_really_cool.yml
```

### Viewing or Modifying Overrides
To view all current queue list overrides and what host has claimed them:

```bash
bundle exec qtrix overrides -l
```

To add a single queue list override:

```bash
bundle exec qtrix overrides -a -q A,B,C
```

To add 10 overrides for the same queue list:

```bash
bundle exec qtrix overrides -a -q X,Y,Z -w 10
```

To remove a single queue list override:

```bash
bundle exec qtrix overrides -d -q A,B,C
```

To remove 10 overrides for the same queue list:

```bash
bundle exec qtrix overrides -d -q X,Y,Z -w 10
```

## API

The entry point to qtrix is the Qtrix module -- a facade contain operations to handle the above functionality.  This is the way anything outside of qtrix interacts with it.  If you use classes underneath the facade, there will be no guarantees of concurrency safety.

### Operations
The following operations are defined in the Qtrix module

```ruby
pry(main)> load 'lib/qtrix.rb'
=> true

pry(main)> Qtrix.operations
=> [:connection_config,
  :operations,
  :configuration_sets,
  :create_configuration_set,
  :remove_configuration_set!,
  :current_configuration_set,
  :activate_configuration_set!,
  :desired_distribution,
  :map_queue_weights,
  :add_override,
  :remove_override,
  :overrides,
  :fetch_queues,
  :clear!]
```

### Configuration Sets
Several of the operations work on configuration sets as follows:

```ruby
pry(main)> Qtrix.configuration_sets
=> [:default]

pry(main)> Qtrix.current_configuration_set
=> :default

pry(main)> Qtrix.create_configuration_set :night
=> true

pry(main)> Qtrix.configuration_sets
=> [:night, :default]

pry(main)> Qtrix.activate_configuration_set! :night
=> "OK"

pry(main)> Qtrix.current_configuration_set
=> :night

pry(main)> Qtrix.activate_configuration_set! :default
=> "OK"

pry(main)> Qtrix.remove_configuration_set! :night
=> true
```

Other operations are targettable to configuraiton sets, but will default to the current configuration set.

### Queue Weightings
You can specify the mappings of weights to queues as follows:

```ruby
Qtrix.map_queue_weights \
  A: 40,
  B: 30,
  C: 20,
  D: 10
```

By default, this will be targetted at the current configuration set.  You can also specify the configuration set you want to change the mappings for as follows:

```ruby
Qtrix.map_queue_weights :night, D: 40, C: 30, B: 20, A: 10
```

### Desired Distribution of Queues
The desired distribution of queues can be obtained with the ```Qtrix#desired_distribution``` method.  This is a list of objects encapsulating the queue name, the namespace, and their weight sorted according to weight.

```ruby
pry(main)> Qtrix.desired_distribution
=> [#<Qtrix::Queue:0x0000010c0cf758
@name=:A,
  @namespace=:current,
  @weight=40.0>,
#<Qtrix::Queue:0x0000010c0cf6e0
  @name=:B,
  @namespace=:current,
  @weight=30.0>,
#<Qtrix::Queue:0x0000010c0cf668
  @name=:C,
  @namespace=:current,
  @weight=20.0>,
#<Qtrix::Queue:0x0000010c0cf5f0
  @name=:D,
  @namespace=:current,
  @weight=10.0>]
```

This is again targettable towards a configuration set.

```ruby
pry(main)> Qtrix.desired_distribution :night
=> [#<Qtrix::Queue:0x007fdec6e73518
@name=:D,
  @namespace=:night,
  @weight=40.0>,
#<Qtrix::Queue:0x007fdec6e73400
  @name=:C,
  @namespace=:night,
  @weight=30.0>,
#<Qtrix::Queue:0x007fdec6e73360
  @name=:B,
  @namespace=:night,
  @weight=20.0>,
#<Qtrix::Queue:0x007fdec6e73298
  @name=:A,
  @namespace=:night,
  @weight=10.0>]
```

### Overrides
Several operations are to interact with overrides -- excplicit configuration of a queue list for some number of worker processes

```ruby
pry(main)> Qtrix.overrides
=> []

pry(main)> Qtrix.add_override [:X, :Y, :Z], 1
=> true

pry(main)> Qtrix.overrides
=> [#<Qtrix::Override:0x007fdec6ba89f0 @host=nil, @queues=[:X, :Y, :Z]>]

pry(main)> Qtrix.add_override [:I, :J, :K], 2
=> true

pry(main)> Qtrix.overrides
=> [#<Qtrix::Override:0x007fdec6f54428 @host=nil, @queues=[:X, :Y, :Z]>,
#<Qtrix::Override:0x007fdec6f51ed0 @host=nil, @queues=[:I, :J, :K]>,
#<Qtrix::Override:0x007fdec6f569d0 @host=nil, @queues=[:I, :J, :K]>]

pry(main)> Qtrix.remove_override([:I, :J, :K], 1)
=> true

pry(main)> Qtrix.overrides
=> [#<Qtrix::Override:0x007fdec4e40a98 @host=nil, @queues=[:X, :Y, :Z]>,
#<Qtrix::Override:0x007fdec4e46808 @host=nil, @queues=[:I, :J, :K]>]

pry(main)> Qtrix.remove_override([:I, :J, :K], 1)
=> true

pry(main)> Qtrix.overrides
=> [#<Qtrix::Override:0x007fdec6aad370 @host=nil, @queues=[:X, :Y, :Z]>]
```

Again, this is all targettable to a config set.

```ruby
pry(main)> Qtrix.add_override :night, [:I, :J, :K], 1
=> true
pry(main)> Qtrix.overrides :night
=> [#<Qtrix::Override:0x007fdec6cb2508 @host=nil, @queues=[:I, :J, :K]>]
```

### Choosing Queues
Anytime a worker host needs some queues for its workers, it should call the Qtrix#fetch_queues method, passing its hostname and the number of workers to obtain queues for.  Overrides will be claimed first, then any additional queues will be obtained from the system that manages the desired distribution.

```ruby
pry(main)> Qtrix.map_queue_weights A: 40, B: 30, C: 20, D: 10
=> 0

pry(main)> Qtrix.add_override [:X, :Y], 1
=> true

pry(main)> Qtrix.fetch_queues("host1", 3)
=> [[:X, :Y], [:A, :B, :C, :D], [:B, :C, :D, :A]]

pry(main)> Qtrix.fetch_queues("host2", 2)
=> [[:C, :D, :A, :B],[:D, :A, :B, :C]]
```

Subsequent calls will return the same list, unless the configuration has changed, in which case new queue lists will be returned according to the new configuration.

```ruby
pry(main)> Qtrix.fetch_queues("host1", 3)
=> [[:X, :Y], [:A, :B, :C, :D], [:B, :C, :D, :A]]

pry(main)> Qtrix.fetch_queues("host2", 2)
=> [[:C, :D, :A, :B],[:D, :A, :B, :C]]

pry(main)> Qtrix.map_queue_weights A: 10, B: 20, C: 30, D: 40
=> 0

pry(main)> Qtrix.fetch_queues("host1", 3)
=> [[:X, :Y], [:D, :C, :B, :A], [:C, :B, :A, :D]]

pry(main)> Qtrix.fetch_queues("host2", 2)
=> [[:B, :A, :D, :C], [:A, :D, :C, :B]]
```

This operation is currently not targettable to a configuration set.  It always operates on the current configuration set.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
