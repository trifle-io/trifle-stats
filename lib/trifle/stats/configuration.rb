# frozen_string_literal: true

require 'tzinfo'

module Trifle
  module Stats
    class Configuration
      attr_writer :granularities
      attr_accessor :time_zone, :beginning_of_week, :designator
      attr_reader :buffer_enabled, :buffer_duration, :buffer_size, :buffer_aggregate

      def initialize
        @default_granularities = %w[1m 1h 1d 1w 1mo 1q 1y]
        @beginning_of_week = :monday
        @time_zone = 'GMT'
        @designator = nil
        @buffer_enabled = true
        @buffer_duration = Trifle::Stats::Buffer::DEFAULT_DURATION
        @buffer_size = Trifle::Stats::Buffer::DEFAULT_SIZE
        @buffer_aggregate = true
        @storage = nil
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

      def storage
        return driver unless buffer_enabled

        @storage ||= Trifle::Stats::Buffer.new(
          driver: driver,
          duration: buffer_duration,
          size: buffer_size,
          aggregate: buffer_aggregate
        )
      end

      def driver=(value)
        reset_buffer!
        @driver = value
      end

      def buffer_duration=(value)
        @buffer_duration = value.to_f
        reset_buffer! if buffer_enabled
      end

      def buffer_size=(value)
        @buffer_size = value.to_i
        reset_buffer! if buffer_enabled
      end

      def buffer_aggregate=(value)
        @buffer_aggregate = value ? true : false
        reset_buffer! if buffer_enabled
      end

      def buffer_enabled=(value)
        @buffer_enabled = value ? true : false
        reset_buffer! unless @buffer_enabled
      end

      def reset_buffer!
        @storage&.shutdown!
        @storage = nil
      end

      private

      def blank?(obj)
        obj.respond_to?(:empty?) ? !!obj.empty? : !obj
      end
    end
  end
end
