# frozen_string_literal: true

require 'trifle/stats/driver/redis'
require 'trifle/stats/driver/process'
require 'trifle/stats/mixins/packer'
require 'trifle/stats/nocturnal'
require 'trifle/stats/configuration'
require 'trifle/stats/operations/timeseries/increment'
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
