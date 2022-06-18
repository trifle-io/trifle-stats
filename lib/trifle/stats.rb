# frozen_string_literal: true

require 'trifle/stats/designator/custom'
require 'trifle/stats/designator/geometric'
require 'trifle/stats/designator/linear'
require 'trifle/stats/driver/mongo'
require 'trifle/stats/driver/postgres'
require 'trifle/stats/driver/process'
require 'trifle/stats/driver/redis'
require 'trifle/stats/mixins/packer'
require 'trifle/stats/nocturnal'
require 'trifle/stats/configuration'
require 'trifle/stats/operations/timeseries/classify'
require 'trifle/stats/operations/timeseries/increment'
require 'trifle/stats/operations/timeseries/set'
require 'trifle/stats/operations/timeseries/values'
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

    def self.values(key:, from:, to:, range:, config: nil)
      Trifle::Stats::Operations::Timeseries::Values.new(
        key: key,
        from: from,
        to: to,
        range: range,
        config: config
      ).perform
    end
  end
end
