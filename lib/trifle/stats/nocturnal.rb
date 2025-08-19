# frozen_string_literal: true

module Trifle
  module Stats
    class Nocturnal # rubocop:disable Metrics/ClassLength
      class Key
        attr_reader :key, :granularity, :at
        attr_accessor :prefix

        def initialize(key:, granularity: nil, at: nil)
          @prefix = nil
          @key = key
          @granularity = granularity
          @at = at
        end

        def join(separator)
          [prefix, key, granularity, at&.to_i].compact.join(separator)
        end

        def identifier(separator)
          if separator
            { key: join(separator) }
          else
            { key: key, granularity: granularity, at: at }.compact
          end
        end
      end

      DAYS_INTO_WEEK = {
        sunday: 0, monday: 1, tuesday: 2, wednesday: 3,
        thursday: 4, friday: 5, saturday: 6
      }.freeze

      def self.timeline(from:, to:, granularity:, config: nil)
        list = []
        from = new(from, config: config).send(granularity)
        to = new(to, config: config).send(granularity)
        item = from.dup
        while item <= to
          list << item
          item = Nocturnal.new(item, config: config).send("next_#{granularity}")
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
          fractions.fetch(:second, 0),
          config.tz.utc_offset
        )
      end

      def second
        change(second: @at.sec)
      end

      def next_second
        Nocturnal.new(
          second + 1,
          config: config
        ).second
      end

      def minute
        change(second: 0)
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
