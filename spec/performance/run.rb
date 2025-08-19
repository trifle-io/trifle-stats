#!/usr/bin/env ruby

require 'bundler/setup'
require 'trifle/stats'
require 'json'
require_relative 'drivers'
require 'benchmark'

count = ARGV[0].to_i
data = JSON.parse(ARGV[1])

puts "Testing #{count}x #{data} increments"
results = Performance::Drivers.new.configurations.map do |config|
  now = Time.now
  assort = Benchmark.realtime do
    count.times do
      Trifle::Stats.assort(key: 'perf_assort', values: data, at: now, config: config)
    end
  end

  assert = Benchmark.realtime do
    count.times do
      Trifle::Stats.assert(key: 'perf_assert', values: data, at: now, config: config)
    end
  end

  track = Benchmark.realtime do
    count.times do
      Trifle::Stats.track(key: 'perf_track', values: data, at: now, config: config)
    end
  end

  values = Benchmark.realtime do
    count.times do
      Trifle::Stats.values(key: 'perf_assort', from: now, to: now, granularity: :hour, config: config)
      Trifle::Stats.values(key: 'perf_assert', from: now, to: now, granularity: :hour, config: config)
      Trifle::Stats.values(key: 'perf_track', from: now, to: now, granularity: :hour, config: config)
    end
  end

  beam = Benchmark.realtime do
    count.times do
      Trifle::Stats.beam(key: 'perf_beam', values: data, at: now, config: config)
    end
  end

  scan = Benchmark.realtime do
    count.times do
      Trifle::Stats.scan(key: 'perf_beam', config: config)
    end
  end

  {name: config.driver.description, assort: assort.round(4), assert: assert.round(4), track: track.round(4), values: values.round(4), beam: beam.round(4), scan: scan.round(4)}
end

puts "DRIVER\t\t\t\t\t\tASSORT\t\tASSERT\t\tTRACK\t\tVALUES\t\tBEAM\t\tSCAN"
results.each do |result|
  puts "#{result[:name]}#{result[:name].length < 32 ? "\t" : nil}\t\t#{result[:assort]}s\t\t#{result[:assert]}s\t\t#{result[:track]}s\t\t#{result[:values]}s\t\t#{result[:beam]}s\t\t#{result[:scan]}s"
end
