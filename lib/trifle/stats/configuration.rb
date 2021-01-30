# frozen_string_literal: true

require 'tzinfo'

module Trifle
  module Stats
    class Configuration
      attr_writer :driver
      attr_accessor :track_ranges, :separator, :time_zone,
                    :beginning_of_week

      def initialize
        @separator = '::'
        @ranges = %i[minute hour day week month quarter year]
        @beginning_of_week = :monday
        @time_zone = 'GMT'
      end

      def tz
        TZInfo::Timezone.get(@time_zone)
      rescue TZInfo::InvalidTimezoneIdentifier => e
        puts "Trifle: #{e} - #{time_zone}; Defaulting to GMT."

        TZInfo::Timezone.get('GMT')
      end

      def ranges
        return @ranges if blank?(track_ranges)

        @ranges & track_ranges
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
