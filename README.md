# Qtrix

For complex applications/domains, Resque and Sidekiq's simple queue
prioritization mechanism (list of queues prioritized left to right) can be
inadequate and prone to problems with resource contention and job/queue
starvation.  Qtrix can help solve these problems by serving as a control center
for intelligently assigning prioritized queue lists for background worker
processes across N number of servers.  Using it in production at PeopleAdmin
has allowed us to minimize the time that jobs lie idle in queues waiting
for worker attention.

It supports the following:

* The concept of a global worker pool by which we can specifically configure individual workers across any number of servers.
* Queue prioritization based on queue weightings.
* Intelligent generation of queue lists for each worker in the global pool.
 * Every queue will be at the head of the list of at least one worker.
 * Queues with a higher priority will appear higher in the list of queues across the global worker pool than queues with a lower priority.
* Real time tweaking of queue prioritization that is propagated across the global worker pool without further effort.
* Overrides to specifically call out any number of workers to process a user-specified list of queues.
* CLI to allow for scriptability of changes in queue prioritization.
* Easy API to allow for other interfaces to be developed.

## CLI
The CLI is provided by the ```qtrix``` executable.  It provides several sub-commands to perform different operations within qtrix as follows:

* **queues**:  Interact with queues
* **overrides**: Interact with the overrides

Using this, you can manipulate the global worker pool's resources so that they are directed to handle any scenario in real time.  It can be run manually on any machine that can establish a connection to the redis instance backing the global worker pool configuration.  It can be scripted via cron or other means to react to changing queue prioritization/resource needs.

### Common Options
The following options are common to all/most commands:

|option|description|
|------|-----------|
|--help|View help information about the command|
|-h    |The redis host to connect to|
|-p    |The redis port to connect to|
|-n    |The redis database number to operate on|

### Viewing or Specifying Queue Priority
To view the current queue priority:

```bash
qtrix queues -l
```

To specify the current queue weightings by inline string:

```bash
qtrix queues -w A:40,B:30,C:20,D:10
```

To specify the current queue weightings by an evaluated yaml file:

```bash
qtrix queues -y ~/my_really_cool.yml
```

### Viewing or Modifying Overrides
To view all current queue list overrides and what host has claimed them:

```bash
qtrix overrides -l
```

To add a single queue list override:

```bash
qtrix overrides -a -q A,B,C
```

To add 10 overrides for the same queue list:

```bash
qtrix overrides -a -q X,Y,Z -w 10
```

To remove a single queue list override:

```bash
qtrix overrides -d -q A,B,C
```

To remove 10 overrides for the same queue list:

```bash
qtrix overrides -d -q X,Y,Z -w 10
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
  :desired_distribution,
  :map_queue_weights,
  :add_override,
  :remove_override,
  :overrides,
  :fetch_queues,
  :clear!]
```

### Queue Weightings
You can specify the mappings of weights to queues as follows:

```ruby
Qtrix.map_queue_weights \
  A: 40,
  B: 30,
  C: 20,
  D: 10
```

### Desired Distribution of Queues
The desired distribution of queues can be obtained with the ```Qtrix#desired_distribution``` method.  This is a list of objects encapsulating the queue name and their weight sorted according to weight.

```ruby
pry(main)> Qtrix.desired_distribution
=> [#<Qtrix::Queue:0x0000010c0cf758
@name=:A,
  @weight=40.0>,
#<Qtrix::Queue:0x0000010c0cf6e0
  @name=:B,
  @weight=30.0>,
#<Qtrix::Queue:0x0000010c0cf668
  @name=:C,
  @weight=20.0>,
#<Qtrix::Queue:0x0000010c0cf5f0
  @name=:D,
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

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
