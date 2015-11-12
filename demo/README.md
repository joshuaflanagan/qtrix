# Qtrix Demo
This demonstrates Qtrix use using the following stack:

1. Qtrix:  Global queue configuration API.
2. [Resque](https://github.com/resque/resque):  asynchronous job processing using redis.
3. [Resque Pool](https://github.com/PeopleAdmin/resque-pool): multi-worker process management.
4. [Stressque](https://github.com/PeopleAdmin/stressque):  Queue-balancing stress testing harness for resque.

## Qtrix tinkering

1.  Load a Qtrix config: ```bundle exec qtrix queues -y qtrix.yml```
1.  Start a pool of workers: ```bundle exec resque-pool```
1.  See the workers and their prioritization (you may have to wait a little until all workers start): ```ps | grep [r]esque```
> Note: if you have `watch` on your system, run this in a terminal and keep it running:
```watch -n 1 "ps | grep [r]esque"```
1.  Start a console: ```bundle exec rake console```
1.  Verify counts of jobs in the console (should be empty):  ```Resque.redis.get ImportJob```
1.  Enqueue jobs in the console:  ```Resque.enqueue ImportJob```
> All of the jobs simply increment a counter with the job's name
1.  Verify counts of jobs in the console (should be 1):  ```Resque.redis.get ImportJob```
1.  Change configuration: ```bundle exec qtrix queues -y qtrix-email-flood.yml```
1.  Check the worker processes again (if not using `watch`): ```ps | grep [r]esque```
1.  Continue to play with Qtrix configurations, enqueing jobs, etc...

## Simulation
1.  Load a Qtrix config: ```bundle exec qtrix queues -y qtrix.yml```
2.  Start a pool of workers: ```bundle exec resque-pool```
3.  Start a console: ```bundle exec rake console```
4.  Start stressque:  ```bundle exec stressque -c stressque.dsl```
5.  Verify counts of jobs in the console:
 1. ```Resque.redis.get AuditJob```
 2. ```Resque.redis.get EmailJob```
 3. ```Resque.redis.get ExportJob```
 4. ```Resque.redis.get ImportJob```

You can modify the stressque.dsl file to your liking to simulate various
load scenarios.

## Load Testing
WIP

## Whoah, how did it do that?
Most of the magic is in the  ```qtrix_config_load.rb``` file.  Here we define a
resque-pool config loader that will obtain queue lists from qtrix and transform
it into the hash resque-pool needs for configuration, then plug it in.  We also
plug in to resque-pool's ```after_prefork``` hook to reconnect our redis
client when new worker processes are forked (this happens after a config change).

Finally, we load ```qtrix_config_load.rb``` in Resque's ```resque:pool:setup```
task in our Rakefile so the wiring happens when it should.

The stress test logic is defined in the stressque.dsl file.  You can learn more
about [stressque here](https://github.com/PeopleAdmin/stressque).
