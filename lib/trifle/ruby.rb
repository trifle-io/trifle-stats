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

    def self.config
      @config ||= Configuration.new
    end

    def self.configure
      yield(config)

      config
    end

    def self.track(key:, at:, values:, configuration: nil)
      Trifle::Ruby::Operations::Timeseries::Increment.new(
        key: key,
        at: at,
        values: values,
        configuration: configuration
      ).perform
    end

    def self.values(key:, from:, to:, range:, configuration: nil)
      Trifle::Ruby::Operations::Timeseries::Values.new(
        key: key,
        from: from,
        to: to,
        range: range,
        configuration: configuration
      ).perform
    end
  end
end
