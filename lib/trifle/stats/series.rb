# frozen_string_literal: true

module Trifle
  module Stats
    class Series
      include Trifle::Stats::Mixins::Packer

      attr_accessor :series

      def initialize(series)
        @series = series
        @series[:values] = self.class.normalize(@series[:values])
      end

      class Aggregator
        def initialize(series)
          @series = series
        end
      end

      def aggregate
        @aggregate ||= Aggregator.new(self)
      end

      def self.register_aggregator(name, klass)
        Aggregator.define_method(name) do |params|
          klass.new.aggregate(series: @series.series, **params)
        end
      end

      class Formatter
        def initialize(series)
          @series = series
        end
      end

      def format
        @format ||= Formatter.new(self)
      end

      def self.register_formatter(name, klass)
        Formatter.define_method(name) do |params, &block|
          klass.new.format(series: @series.series, **params, &block)
        end
      end

      class Transponder
        def initialize(series)
          @series = series
        end
      end

      def transpond
        @transpond ||= Transponder.new(self)
      end

      def self.register_transponder(name, klass)
        Transponder.define_method(name) do |params|
          @series.series = klass.new.transpond(series: @series.series, **params)
        end
      end
    end
  end
end
