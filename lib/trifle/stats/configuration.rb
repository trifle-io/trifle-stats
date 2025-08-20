# frozen_string_literal: true

require 'tzinfo'

module Trifle
  module Stats
    class Configuration
      attr_writer :driver, :granularities
      attr_accessor :time_zone, :beginning_of_week, :designator

      def initialize
        @default_granularities = %w[1m 1h 1d 1w 1mo 1q 1y]
        @beginning_of_week = :monday
        @time_zone = 'GMT'
        @designator = nil
      end

      def tz
        TZInfo::Timezone.get(@time_zone)
      rescue TZInfo::InvalidTimezoneIdentifier => e
        puts "Trifle: #{e} - #{time_zone}; Defaulting to GMT."

        TZInfo::Timezone.get('GMT')
      end

      def granularities
        (@granularities || @default_granularities).uniq.filter do |grn|
          Trifle::Stats::Nocturnal::Parser.new(grn).valid?
        end
      end

      def driver
        raise DriverNotFound if @driver.nil?

        @driver
      end

      private

      def blank?(obj)
        obj.respond_to?(:empty?) ? !!obj.empty? : !obj
      end
    end
  end
end
