# Trifle

Trifle - simple analytics backed by Redis, Postgres, MongoDB, Google Analytics, Segment, or whatever. [^1]

Trifle is a _way too_ simple timeline analytics that helps you track custom metrics. Automatically increments counters for each enabled range. It supports timezones and different week beginning.

[^1] TBH only Redis for now 💔.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'trifle-ruby'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install trifle-ruby

## Usage

You don't need to use it with Rails, but you still need to run `Trifle::Ruby.configure`. If youre running it with Rails, create `config/initializers/trifle-ruby.rb` and configure the gem.

```ruby
Trifle::Ruby.configure do |config|
  config.driver = Trifle::Ruby::Driver::Redis.new
  config.track_ranges = [:hour, :day]
  config.time_zone = 'Europe/Bratislava'
  config.beginning_of_week = :monday
end
```

Available ranges are `:minute`, `:hour`, `:day`, `:week`, `:month`, `:quarter`, `:year`.

Now track your first metrics
```ruby
Trifle::Ruby.track(key: 'event::logs', at: Time.zone.now, values: {count: 1, duration: 2, lines: 241})
=> [{2021-01-25 16:00:00 +0100=>{:count=>1, :duration=>2, :lines=>241}}, {2021-01-25 00:00:00 +0100=>{:count=>1, :duration=>2, :lines=>241}}]
# or do it few more times
Trifle::Ruby.track(key: 'event::logs', at: Time.zone.now, values: {count: 1, duration: 1, lines: 56})
=> [{2021-01-25 16:00:00 +0100=>{:count=>1, :duration=>1, :lines=>56}}, {2021-01-25 00:00:00 +0100=>{:count=>1, :duration=>1, :lines=>56}}]
Trifle::Ruby.track(key: 'event::logs', at: Time.zone.now, values: {count: 1, duration: 5, lines: 361})
=> [{2021-01-25 16:00:00 +0100=>{:count=>1, :duration=>5, :lines=>361}}, {2021-01-25 00:00:00 +0100=>{:count=>1, :duration=>5, :lines=>361}}]
```

You can then retrieve your values for specific `range`.
```ruby
Trifle::Ruby.values_for(key: 'event::logs', from: Time.now.beginning_of_day, to: Time.now.end_of_day, range: :day)
=> [{2021-01-25 00:00:00 +0100=>{"count"=>3, "duration"=>8, "lines"=>658}}]
```

You can also store nested counters like
```ruby
Trifle::Ruby.track(key: 'event::logs', at: Time.zone.now, values: {
  count: 1,
  duration: {
    parsing: 21,
    compression: 8,
    upload: 1
  },
  lines: 25432754
})
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/trifle-io/trifle-ruby.
