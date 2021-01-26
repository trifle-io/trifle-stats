# frozen_string_literal: true

module Trifle
  module Ruby
    class Nocturnal
      DAYS_INTO_WEEK = {
        sunday: 0, monday: 1, tuesday: 2, wednesday: 3,
        thursday: 4, friday: 5, saturday: 6
      }.freeze

      def self.timeline(from:, to:, range:)
        list = []
        from = new(from).send("beginning_of_#{range}")
        to = new(to).send("beginning_of_#{range}")
        item = from.dup
        while item <= to
          list << item
          item = Nocturnal.new(list.last).send("next_#{range}")
        end
        list
      end

      def initialize(at)
        @at = at
        @tz = Trifle::Ruby.config.tz
      end

      def change(**fractions)
        Time.new(
          fractions.fetch(:year, @at.year),
          fractions.fetch(:month, @at.month),
          fractions.fetch(:day, @at.day),
          fractions.fetch(:hour, @at.hour),
          fractions.fetch(:minute, @at.min),
          0, # second
          @tz.utc_offset
        )
      end

      def beginning_of_minute
        change
      end

      def next_minute
        Nocturnal.new(
          beginning_of_minute + 60
        ).beginning_of_minute
      end

      def beginning_of_hour
        change(minute: 0)
      end

      def next_hour
        Nocturnal.new(
          beginning_of_hour + 60 * 60
        ).beginning_of_hour
      end

      def beginning_of_day
        change(hour: 0, minute: 0)
      end

      def next_day
        Nocturnal.new(
          beginning_of_day + 60 * 60 * 24
        ).beginning_of_day
      end

      def beginning_of_week
        today = beginning_of_day

        (today.to_date - days_to_week_start).to_time
      end

      def next_week
        Nocturnal.new(
          beginning_of_week + 60 * 60 * 24 * 7
        ).beginning_of_week
      end

      def days_to_week_start
        start_day_number = DAYS_INTO_WEEK.fetch(
          Trifle::Ruby.config.beginning_of_week
        )

        (@at.wday - start_day_number) % 7
      end

      def beginning_of_month
        change(day: 1, hour: 0, minute: 0)
      end

      def next_month
        Nocturnal.new(
          beginning_of_month + 60 * 60 * 24 * 31
        ).beginning_of_month
      end

      def beginning_of_quarter
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
          beginning_of_quarter + 60 * 60 * 24 * 31 * 3
        ).beginning_of_quarter
      end

      def beginning_of_year
        change(month: 1, day: 1, hour: 0, minute: 0)
      end

      def next_year
        Nocturnal.new(
          beginning_of_year + 60 * 60 * 24 * 31 * 12
        ).beginning_of_year
      end
    end
  end
end
