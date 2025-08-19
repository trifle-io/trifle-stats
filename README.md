# Trifle::Stats

[![Gem Version](https://badge.fury.io/rb/trifle-stats.svg)](https://rubygems.org/gems/trifle-stats)
[![Ruby](https://github.com/trifle-io/trifle-stats/workflows/Ruby/badge.svg?branch=main)](https://github.com/trifle-io/trifle-stats)

Simple analytics backed by Redis, Postgres, MongoDB, Google Analytics, Segment, or whatever. It gets you from having bunch of events occuring within few minutes to being able to say what happened on 25th January 2021.

## Documentation

For comprehensive guides, API reference, and examples, visit [trifle.io/trifle-stats-rb](https://trifle.io/trifle-stats-rb)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'trifle-stats'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install trifle-stats
```

## Quick Start

### 1. Configure

```ruby
require 'trifle/stats'

Trifle::Stats.configure do |config|
  config.driver = Trifle::Stats::Driver::Redis.new(Redis.new)
  config.track_granularities = [:minute, :hour, :day, :week, :month, :quarter, :year]
end
```

### 2. Track events

```ruby
Trifle::Stats.track(key: 'event::logs', at: Time.now, values: { count: 1, duration: 2.11 })
```

### 3. Retrieve values

```ruby
Trifle::Stats.values(key: 'event::logs', from: 1.month.ago, to: Time.now, granularity: :day)
#=> {:at=>[Wed, 25 Jan 2023 00:00:00 +0000], :values=>[{"count"=>1, "duration"=>2.11}]}
```

## Drivers

Trifle::Stats supports multiple backends:

- **Redis** - Fast, in-memory storage
- **Postgres** - SQL database with JSONB support
- **SQLite** - SQL database in a file
- **MongoDB** - Document database
- **Process** - Thread-safe in-memory storage (development/testing)
- **Dummy** - No-op driver for disabled analytics

## Features

- **Multiple time granularities** - Track data across different time periods
- **Custom aggregators** - Sum, average, min, max with custom logic
- **Series operations** - Advanced data manipulation and calculations
- **Performance optimized** - Efficient storage and retrieval patterns
- **Driver flexibility** - Switch between storage backends easily

## Testing

Tests are run against all supported drivers. To run the test suite:

```bash
$ bundle exec rspec
```

Ensure Redis, Postgres, and MongoDB are running locally. The test suite will handle database setup automatically.

Tests are meant to be **simple and isolated**. Every test should be **independent** and able to run in any order. Tests should be **self-contained** and set up their own configuration. This makes it easier to debug and maintain the test suite.

Use **single layer testing** to focus on testing a specific class or module in isolation. Use **appropriate stubbing** for driver methods when testing higher-level operations.

Driver tests use real database connections for accurate behavior validation. The `Process` driver is preferred for in-memory testing environments.

**Repeat yourself** in test setup for clarity rather than complex shared setups that can hide dependencies.

For performance testing:

```bash
$ cd specs/performance
$ bundle install
$ ruby run.rb 100 '{"a":1}'
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/trifle-io/trifle-stats.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
