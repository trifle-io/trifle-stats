# frozen_string_literal: true

require 'tzinfo'

module Trifle
  module Stats
    class Configuration
      attr_writer :driver
      attr_accessor :track_granularities, :time_zone, :beginning_of_week, :designator

      def initialize
        @granularities = %i[second minute hour day week month quarter year]
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
        return @granularities if blank?(track_granularities)

        @granularities & track_granularities
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
