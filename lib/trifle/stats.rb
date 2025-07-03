# frozen_string_literal: true

require 'trifle/stats/mixins/packer'
require 'trifle/stats/nocturnal'
require 'trifle/stats/series'
require 'trifle/stats/aggregator/avg'
require 'trifle/stats/aggregator/max'
require 'trifle/stats/aggregator/min'
require 'trifle/stats/aggregator/sum'
require 'trifle/stats/designator/custom'
require 'trifle/stats/designator/geometric'
require 'trifle/stats/designator/linear'
require 'trifle/stats/driver/mongo'
require 'trifle/stats/driver/postgres'
require 'trifle/stats/driver/process'
require 'trifle/stats/driver/redis'
require 'trifle/stats/driver/sqlite'
require 'trifle/stats/formatter/category'
require 'trifle/stats/formatter/timeline'
require 'trifle/stats/configuration'
require 'trifle/stats/operations/timeseries/classify'
require 'trifle/stats/operations/timeseries/increment'
require 'trifle/stats/operations/timeseries/set'
require 'trifle/stats/operations/timeseries/values'
require 'trifle/stats/operations/status/beam'
require 'trifle/stats/operations/status/scan'
require 'trifle/stats/transponder/average'
require 'trifle/stats/transponder/ratio'
require 'trifle/stats/transponder/standard_deviation'
require 'trifle/stats/version'

module Trifle
  module Stats
    class Error < StandardError; end
    class DriverNotFound < Error; end

    def self.default
      @default ||= Configuration.new
    end

    def self.configure
      yield(default)

      default
    end

    def self.track(key:, at:, values:, config: nil)
      Trifle::Stats::Operations::Timeseries::Increment.new(
        key: key,
        at: at,
        values: values,
        config: config
      ).perform
    end

    def self.assert(key:, at:, values:, config: nil)
      Trifle::Stats::Operations::Timeseries::Set.new(
        key: key,
        at: at,
        values: values,
        config: config
      ).perform
    end

    def self.assort(key:, at:, values:, config: nil)
      Trifle::Stats::Operations::Timeseries::Classify.new(
        key: key,
        at: at,
        values: values,
        config: config
      ).perform
    end

    def self.values(key:, from:, to:, range:, skip_blanks: false, config: nil) # rubocop:disable Metrics/ParameterLists
      Trifle::Stats::Operations::Timeseries::Values.new(
        key: key,
        from: from,
        to: to,
        range: range,
        skip_blanks: skip_blanks,
        config: config
      ).perform
    end

    def self.series(**params)
      Trifle::Stats::Series.new(values(**params))
    end

    def self.beam(key:, at:, values:, config: nil)
      Trifle::Stats::Operations::Status::Beam.new(
        key: key,
        at: at,
        values: values,
        config: config
      ).perform
    end

    def self.scan(key:, config: nil)
      Trifle::Stats::Operations::Status::Scan.new(
        key: key,
        config: config
      ).perform
    end
  end
end
