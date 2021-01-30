# Trifle

[![Gem Version](https://badge.fury.io/rb/trifle-stats.svg)](https://badge.fury.io/rb/trifle-stats)
![Ruby](https://github.com/trifle-io/trifle-stats/workflows/Ruby/badge.svg?branch=main)
[![Gitpod ready-to-code](https://img.shields.io/badge/Gitpod-ready--to--code-blue?logo=gitpod)](https://gitpod.io/#https://github.com/trifle-io/trifle-stats)

Simple analytics backed by Redis, Postgres, MongoDB, Google Analytics, Segment, or whatever. [^1]

Trifle is a _way too_ simple timeline analytics that helps you track custom metrics. Automatically increments counters for each enabled range. It supports timezones and different week beginning.

[^1] TBH only Redis for now 💔.

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

### Get values

Retrieve your values for specific `range`.
```ruby
Trifle::Stats.values(key: 'event::logs', from: Time.now, to: Time.now, range: :day)
=> [{2021-01-25 00:00:00 +0100=>{"count"=>3, "duration"=>8, "lines"=>658}}]
```

### Configuration

Configuration allows you to specify:
- `driver` - backend driver used to persist and retrieve data.
- `track_ranges` - list of timeline ranges you would like to track. Value must be list of symbols, defaults to `[:minute, :hour, :day, :week, :month, :quarter, :year]`.
- `separator` - keys can get serialized in backend, separator is used to join these values. Value must be string, defaults to `::`.
- `time_zone` - TZInfo zone to properly generate range for timeline values. Value must be valid TZ string identifier, otherwise it defaults and fallbacks to `'GMT'`.
- `beginning_of_week` - first day of week. Value must be string, defaults to `:monday`.

Gem expecs global configuration to be present. You can do this by creating initializer, or calling it on the beginning of your ruby script.

Custom configuration can be passed as a keyword argument to `Resource` objects and all module methods (`track`, `values`). This way you can pass different driver or ranges for different type of data youre storing - ie set different ranges or set expiration date on your data.

```ruby
configuration = Trifle::Stats::Configuration.new
configuration.driver = Trifle::Stats::Driver::Redis.new
configuration.track_ranges = [:day]
configuration.time_zone = 'GMT'
configuration.separator = '#'

# or use different driver
mongo_configuration = Trifle::Stats::Configuration.new
mongo_configuration.driver = Trifle::Stats::Driver::MongoDB.new
mongo_configuration.time_zone = 'Asia/Dubai'
```

You can then pass it into module methods.
```ruby
Trifle::Stats.track(key: 'event#checkout', at: Time.now, values: {count: 1}, config: configuration)

Trifle::Stats.track(key: 'event#checkout', at: Time.now, values: {count: 1}, config: mongo_configuration)
```

### Driver

Driver is a wrapper around existing client libraries that talk to DB or API. It is used to store and retrieve values. You can read more in [Driver Readme](https://github.com/trifle-io/trifle-stats/tree/main/lib/trifle/ruby/driver).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Gitpod

This repository comes Gitpod ready. If you wanna try and get your hands dirty with Trifle, click [here](https://gitpod.io/#https://github.com/trifle-io/trifle-stats) and watch magic happening.

It launches from custom base image that includes Redis, MongoDB, Postgres & MariaDB. This should give you enough playground to launch `./bin/console` and start messing around. You can see the Gitpod image in the [hub](https://hub.docker.com/r/trifle/gitpod).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/trifle-io/trifle-stats.
