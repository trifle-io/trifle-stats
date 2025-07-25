# Trifle::Stats

[![Gem Version](https://badge.fury.io/rb/trifle-stats.svg)](https://badge.fury.io/rb/trifle-stats)
![Ruby](https://github.com/trifle-io/trifle-stats/workflows/Ruby/badge.svg?branch=main)
[![Gitpod ready-to-code](https://img.shields.io/badge/Gitpod-ready--to--code-blue?logo=gitpod)](https://gitpod.io/#https://github.com/trifle-io/trifle-stats)

Simple analytics backed by Redis, Postgres, MongoDB, Google Analytics, Segment, or whatever. [^1]

`Trifle::Stats` is a _way too_ simple timeline analytics that helps you track custom metrics. Automatically increments counters for each enabled range. It supports timezones and different week beginning.

[^1]: TBH only Redis, Postgres and MongoDB for now 💔.

## Documentation

You can find guides and documentation at https://trifle.io/trifle-stats

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'trifle-stats'
```

And then execute:

```sh
$ bundle install
```

Or install it yourself as:

```sh
$ gem install trifle-stats
```

Depending on driver you would like to use, make sure you add required gems into your `Gemfile`.
```ruby
gem 'mongo', '>= 2.14.0'
gem 'pg', '>= 1.2'
gem 'redis', '>= 4.2'
```

## Usage

You don't need to use it with Rails, but you still need to run `Trifle::Stats.configure`. If youre running it with Rails, create `config/initializers/trifle-stats.rb` and configure the gem.

```ruby
Trifle::Stats.configure do |config|
  config.driver = Trifle::Stats::Driver::Redis.new
  config.track_ranges = [:hour, :day]
  config.time_zone = 'Europe/Bratislava'
  config.beginning_of_week = :monday
end
```

### Track values

Track your first metrics

```ruby
Trifle::Stats.track(key: 'event::logs', at: Time.now, values: {count: 1, duration: 2, lines: 241})
=> [{2021-01-25 16:00:00 +0100=>{:count=>1, :duration=>2, :lines=>241}}, {2021-01-25 00:00:00 +0100=>{:count=>1, :duration=>2, :lines=>241}}]
```

Then do it few more times

```ruby
Trifle::Stats.track(key: 'event::logs', at: Time.now, values: {count: 1, duration: 1, lines: 56})
=> [{2021-01-25 16:00:00 +0100=>{:count=>1, :duration=>1, :lines=>56}}, {2021-01-25 00:00:00 +0100=>{:count=>1, :duration=>1, :lines=>56}}]
Trifle::Stats.track(key: 'event::logs', at: Time.now, values: {count: 1, duration: 5, lines: 361})
=> [{2021-01-25 16:00:00 +0100=>{:count=>1, :duration=>5, :lines=>361}}, {2021-01-25 00:00:00 +0100=>{:count=>1, :duration=>5, :lines=>361}}]
```

You can also store nested counters like

```ruby
Trifle::Stats.track(key: 'event::logs', at: Time.now, values: {
  count: 1,
  duration: {
    parsing: 21,
    compression: 8,
    upload: 1
  },
  lines: 25432754
})
```

#### Get values

Retrieve your values for specific `range`. Adding increments above will return sum of all the values you've tracked.

```ruby
Trifle::Stats.values(key: 'event::logs', from: Time.now, to: Time.now, range: :day)
=> {:at=>[2021-01-25 00:00:00 +0200], :values=>[{"count"=>3, "duration"=>8, "lines"=>658}]}
```

### Assert values

Asserting values works same way like incrementing, but instead of increment, it sets the value. Duh.

Set your first metrics

```ruby
Trifle::Stats.assert(key: 'event::logs', at: Time.now, values: {count: 1, duration: 2, lines: 241})
=> [{2021-01-25 16:00:00 +0100=>{:count=>1, :duration=>2, :lines=>241}}, {2021-01-25 00:00:00 +0100=>{:count=>1, :duration=>2, :lines=>241}}]
```

Then do it few more times

```ruby
Trifle::Stats.assert(key: 'event::logs', at: Time.now, values: {count: 1, duration: 1, lines: 56})
=> [{2021-01-25 16:00:00 +0100=>{:count=>1, :duration=>1, :lines=>56}}, {2021-01-25 00:00:00 +0100=>{:count=>1, :duration=>1, :lines=>56}}]
Trifle::Stats.assert(key: 'event::logs', at: Time.now, values: {count: 1, duration: 5, lines: 361})
=> [{2021-01-25 16:00:00 +0100=>{:count=>1, :duration=>5, :lines=>361}}, {2021-01-25 00:00:00 +0100=>{:count=>1, :duration=>5, :lines=>361}}]
```

#### Get values

Retrieve your values for specific `range`. As you just used `assert` above, it will return latest value you've asserted.

```ruby
Trifle::Stats.values(key: 'event::logs', from: Time.now, to: Time.now, range: :day)
=> {:at=>[2021-01-25 00:00:00 +0200], :values=>[{"count"=>1, "duration"=>5, "lines"=>361}]}
```

## Testing

### Testing Principles

Tests are structured to be simple, isolated, and mirror the class structure. Each test is independent and self-contained.

#### Key Rules:

1. **Keep tests simple and isolated** - Each test should focus on a single class/method
2. **Independent tests** - Tests should not depend on each other and can be run in any order
3. **Self-contained setup** - Every test configures its own variables and dependencies
4. **Single layer testing** - Test only the specific class, not multiple layers of functionality
5. **Use appropriate stubbing** - When testing operations, stub driver methods. Let driver tests verify driver behavior
6. **Repeat yourself** - It's okay to repeat setup code for clarity and independence

#### Driver Testing:

- Driver tests use **real database connections** (Redis, PostgreSQL, MongoDB, SQLite)
- Clean data between tests to ensure isolation
- Use appropriate test databases (e.g., Redis database 15, test-specific DB names)
- The **Process driver** is ideal for testing environments as it uses in-memory storage

#### Test Structure:

Tests follow the same structure as the classes they test:
- `spec/stats/driver/` - Driver class tests
- `spec/stats/operations/` - Operation class tests  
- `spec/stats/mixins/` - Mixin tests

This approach makes it easier to see initial configuration and expected results for each test.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/trifle-io/trifle-stats.
