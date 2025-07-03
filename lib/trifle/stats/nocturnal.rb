# frozen_string_literal: true

module Trifle
  module Stats
    class Nocturnal # rubocop:disable Metrics/ClassLength
      class Key
        attr_reader :key, :range, :at
        attr_accessor :prefix

        def initialize(key:, range: nil, at: nil)
          @prefix = nil
          @key = key
          @range = range
          @at = at
        end

        def join(separator)
          [prefix, key, range, at&.to_i].compact.join(separator)
        end

        def identifier(separator)
          if separator
            { key: join(separator) }
          else
            { key: key, range: range, at: at }.compact
          end
        end
      end

      DAYS_INTO_WEEK = {
        sunday: 0, monday: 1, tuesday: 2, wednesday: 3,
        thursday: 4, friday: 5, saturday: 6
      }.freeze

      def self.timeline(from:, to:, range:, config: nil)
        list = []
        from = new(from, config: config).send(range)
        to = new(to, config: config).send(range)
        item = from.dup
        while item <= to
          list << item
          item = Nocturnal.new(item, config: config).send("next_#{range}")
        end
        list
      end

      def initialize(at, config: nil)
        @at = at
        @config = config
      end

      def config
        @config || Trifle::Stats.default
      end

      def change(**fractions)
        Time.new(
          fractions.fetch(:year, @at.year),
          fractions.fetch(:month, @at.month),
          fractions.fetch(:day, @at.day),
          fractions.fetch(:hour, @at.hour),
          fractions.fetch(:minute, @at.min),
          0, # second
          config.tz.utc_offset
        )
      end

      def minute
        change
      end

      def next_minute
        Nocturnal.new(
          minute + 60,
          config: config
        ).minute
      end

      def hour
        change(minute: 0)
      end

      def next_hour
        Nocturnal.new(
          hour + 60 * 60,
          config: config
        ).hour
      end

      def day
        change(hour: 0, minute: 0)
      end

      def next_day
        Nocturnal.new(
          day + 60 * 60 * 24,
          config: config
        ).day
      end

      def week
        today = day

        (today.to_date - days_to_week_start).to_time
      end

      def next_week
        Nocturnal.new(
          week + 60 * 60 * 24 * 7,
          config: config
        ).week
      end

      def days_to_week_start
        start_day_number = DAYS_INTO_WEEK.fetch(
          config.beginning_of_week
        )

        (@at.wday - start_day_number) % 7
      end

      def month
        change(day: 1, hour: 0, minute: 0)
      end

      def next_month
        Nocturnal.new(
          month + 60 * 60 * 24 * 31,
          config: config
        ).month
      end

      def quarter
        first_quarter_month = @at.month - (2 + @at.month) % 3

        change(
          month: first_quarter_month,
          day: 1,
          hour: 0,
          minute: 0
        )
      end

      def next_quarter
        Nocturnal.new(
          quarter + 60 * 60 * 24 * 31 * 3,
          config: config
        ).quarter
      end

      def year
        change(month: 1, day: 1, hour: 0, minute: 0)
      end

      def next_year
        Nocturnal.new(
          year + 60 * 60 * 24 * 31 * 12,
          config: config
        ).year
      end
    end
  end
end
