# frozen_string_literal: true

require 'trifle/ruby/driver/redis'
require 'trifle/ruby/mixins/packer'
require 'trifle/ruby/nocturnal'
require 'trifle/ruby/configuration'
require 'trifle/ruby/operations/timeseries/increment'
require 'trifle/ruby/operations/timeseries/values'
require 'trifle/ruby/version'

module Trifle
  module Ruby
    class Error < StandardError; end
    class DriverNotFound < Error; end

    def self.default
      @config ||= Configuration.new
    end

    def self.configure
      yield(default)

      default
    end

    def self.track(key:, at:, values:, config: nil)
      Trifle::Ruby::Operations::Timeseries::Increment.new(
        key: key,
        at: at,
        values: values,
        config: config
      ).perform
    end

    def self.values(key:, from:, to:, range:, config: nil)
      Trifle::Ruby::Operations::Timeseries::Values.new(
        key: key,
        from: from,
        to: to,
        range: range,
        config: config
      ).perform
    end
  end
end
