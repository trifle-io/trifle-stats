# Driver

Driver is a wrapper class that persists and retrieves values from backend. It needs to implement:
- `inc(key:, **values)` method to store values
- `get(key:)` method to retrieve values

## Packer Mixin

Some databases cannot store nested hashes/values. Or they cannot perform increment on nested values that does not exist. For this reason you can use Packer mixin that helps you convert values to dot notation.

```ruby
class Sample
  include Trifle::Stats::Mixins::Packer
end

values = { a: 1, b: { c: 22, d: 33 } }
=> {:a=>1, :b=>{:c=>22, :d=>33}}

packed = Sample.pack(hash: values)
=> {"a"=>1, "b.c"=>22, "b.d"=>33}

Sample.unpack(hash: packed)
=> {"a"=>1, "b"=>{"c"=>22, "d"=>33}}
```

## Dummy driver

Sample of using custom driver that does, well, nothing useful.

```ruby
irb(main):001:1* class Dummy
irb(main):002:2*   def inc(key:, **values)
irb(main):003:2*     puts "Dumping #{key} => #{values}"
irb(main):004:1*   end
irb(main):005:2*   def get(key:)
irb(main):006:2*     puts "Random for #{key}"
irb(main):007:2*     { count: rand(1000) }
irb(main):008:1*   end
irb(main):009:0> end
=> :get

irb(main):010:0> c = Trifle::Stats::Configuration.new
=> #<Trifle::Stats::Configuration:0x00007fe179aed848 @separator="::", @ranges=[:minute, :hour, :day, :week, :month, :quarter, :year], @beginning_of_week=:monday, @time_zone="GMT">

irb(main):011:0> c.driver = Dummy.new
=> #<Dummy:0x00007fe176302ac8>

irb(main):012:0> c.track_ranges = [:minute, :hour]
=> [:minute, :hour]

irb(main):013:0> Trifle::Stats.track(key: 'sample', at: Time.now, values: {count: 1}, config: c)
Dumping sample::minute::1611696240 => {:count=>1}
Dumping sample::hour::1611694800 => {:count=>1}
=> [{2021-01-26 21:24:00 +0000=>{:count=>1}}, {2021-01-26 21:00:00 +0000=>{:count=>1}}]

irb(main):014:0> Trifle::Stats.values(key: 'sample', from: Time.now, to: Time.now, range: :hour, config: c)
Random for sample::hour::1611694800
=> [{2021-01-26 21:00:00 +0000=>{:count=>405}}]
```
