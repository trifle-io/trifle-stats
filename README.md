# Trifle

[![Gem Version](https://badge.fury.io/rb/trifle-stats.svg)](https://badge.fury.io/rb/trifle-stats)
![Ruby](https://github.com/trifle-io/trifle-stats/workflows/Ruby/badge.svg?branch=main)
[![Gitpod ready-to-code](https://img.shields.io/badge/Gitpod-ready--to--code-blue?logo=gitpod)](https://gitpod.io/#https://github.com/trifle-io/trifle-stats)

Simple analytics backed by Redis, Postgres, MongoDB, Google Analytics, Segment, or whatever. [^1]

`Trifle::Stats` is a _way too_ simple timeline analytics that helps you track custom metrics. Automatically increments counters for each enabled range. It supports timezones and different week beginning.

[^1]: TBH only Redis for now 💔.

## Documentation

You can find guides and documentation at https://trifle.io/docs/stats

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'trifle-stats'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install trifle-stats

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

Available ranges are `:minute`, `:hour`, `:day`, `:week`, `:month`, `:quarter`, `:year`.

Now track your first metrics
```ruby
Trifle::Stats.track(key: 'event::logs', at: Time.now, values: {count: 1, duration: 2, lines: 241})
=> [{2021-01-25 16:00:00 +0100=>{:count=>1, :duration=>2, :lines=>241}}, {2021-01-25 00:00:00 +0100=>{:count=>1, :duration=>2, :lines=>241}}]
# or do it few more times
Trifle::Stats.track(key: 'event::logs', at: Time.now, values: {count: 1, duration: 1, lines: 56})
=> [{2021-01-25 16:00:00 +0100=>{:count=>1, :duration=>1, :lines=>56}}, {2021-01-25 00:00:00 +0100=>{:count=>1, :duration=>1, :lines=>56}}]
Trifle::Stats.track(key: 'event::logs', at: Time.now, values: {count: 1, duration: 5, lines: 361})
=> [{2021-01-25 16:00:00 +0100=>{:count=>1, :duration=>5, :lines=>361}}, {2021-01-25 00:00:00 +0100=>{:count=>1, :duration=>5, :lines=>361}}]
```

### Get values

Retrieve your values for specific `range`.
```ruby
Trifle::Stats.values(key: 'event::logs', from: Time.now, to: Time.now, range: :day)
=> [{2021-01-25 00:00:00 +0100=>{"count"=>3, "duration"=>8, "lines"=>658}}]
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/trifle-io/trifle-stats.
