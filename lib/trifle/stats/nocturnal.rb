# frozen_string_literal: true

module Trifle
  module Stats
    class Nocturnal # rubocop:disable Metrics/ClassLength
      UNIT_MAP = {
        's' => :second,
        'm' => :minute,
        'h' => :hour,
        'd' => :day,
        'w' => :week,
        'mo' => :month,
        'q' => :quarter,
        'y' => :year
      }.freeze

      DAYS_INTO_WEEK = {
        sunday: 0, monday: 1, tuesday: 2, wednesday: 3,
        thursday: 4, friday: 5, saturday: 6
      }.freeze

      def self.timeline(from:, to:, offset:, unit:, config: nil)
        list = []
        from = new(from, config: config).floor(offset, unit)
        to = new(to, config: config).floor(offset, unit)
        item = from.dup
        while item <= to
          list << item
          item = new(item, config: config).add(offset, unit)
        end
        list
      end

      attr_reader :time

      def initialize(time, config: nil)
        @time = time
        @config = config
      end

      def config
        @config || Trifle::Stats.default
      end

      def add(offset, unit) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
        raise ArgumentError, "Expected Time object, got #{time.class}" unless time.is_a?(Time)
        raise ArgumentError, 'Offset must be numeric' unless offset.is_a?(Numeric)
        raise ArgumentError, "Invalid unit: #{unit}" unless Trifle::Stats::Nocturnal::UNIT_MAP.values.include?(unit)

        case unit
        when :second
          time + offset
        when :minute
          time + (offset * 60)
        when :hour
          time + (offset * 3600)
        when :day
          time + (offset * 86_400)
        when :week
          time + (offset * 604_800)
        when :month
          # Handle months carefully due to varying lengths
          result = time
          offset.times do
            result = add_one_month(result)
          end
          result
        when :quarter
          # Add 3 months for each quarter
          result = time
          (offset * 3).times do
            result = add_one_month(result)
          end
          result
        when :year
          # Handle years carefully due to leap years
          begin
            Time.new(
              time.year + offset,
              time.month,
              time.day,
              time.hour,
              time.min,
              time.sec,
              config.tz.utc_offset
            )
          rescue ArgumentError
            # Handle edge cases like Feb 29 in non-leap years
            Time.new(
              time.year + amount,
              time.month,
              [time.day, days_in_month(time.year + amount, time.month)].min,
              time.hour,
              time.min,
              time.sec,
              time.utc_offset
            )
          end
        end
      end

      def floor(offset, unit) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
        raise ArgumentError, "Expected Time object, got #{time.class}" unless time.is_a?(Time)
        raise ArgumentError, 'Segment size must be positive' unless offset.positive?
        raise ArgumentError, "Invalid unit: #{unit}" unless Trifle::Stats::Nocturnal::UNIT_MAP.values.include?(unit)

        case unit
        when :second
          # Floor to second segment boundary
          total_seconds = time.sec
          floored_seconds = (total_seconds / offset) * offset
          Time.new(time.year, time.month, time.day, time.hour, time.min, floored_seconds, time.utc_offset)

        when :minute
          # Floor to minute segment boundary (segments start from beginning of hour)
          minutes_from_hour_start = time.min
          floored_minutes = (minutes_from_hour_start / offset) * offset
          Time.new(time.year, time.month, time.day, time.hour, floored_minutes, 0, time.utc_offset)

        when :hour
          # Floor to hour segment boundary (segments start from beginning of day)
          hours_from_day_start = time.hour
          floored_hours = (hours_from_day_start / offset) * offset
          Time.new(time.year, time.month, time.day, floored_hours, 0, 0, time.utc_offset)

        when :day
          # Floor to day segment boundary (segments start from beginning of year)
          days_from_year_start = time.yday - 1 # yday is 1-indexed, we want 0-indexed
          floored_days = (days_from_year_start / offset) * offset
          year_start = Time.new(time.year, 1, 1, 0, 0, 0, time.utc_offset)
          result_date = year_start.to_date + floored_days
          Time.new(result_date.year, result_date.month, result_date.day, 0, 0, 0, time.utc_offset)

        when :week
          # Floor to week segment boundary (segments start from beginning of year)
          year_start = Time.new(time.year, 1, 1, 0, 0, 0, time.utc_offset)

          # Find the first week boundary of the year based on week_start
          week_start_offset = DAYS_INTO_WEEK.fetch(
            config.beginning_of_week
          )
          year_start_wday = year_start.wday
          days_to_first_week_start = (week_start_offset - year_start_wday) % 7
          first_week_start = year_start.to_date + days_to_first_week_start
          first_week_start_time = Time.new(first_week_start.year, first_week_start.month, first_week_start.day, 0, 0, 0, time.utc_offset) # rubocop:disable Layout/LineLength

          # If current time is before first week boundary, use year start
          if time < first_week_start_time
            year_start
          else
            # Calculate weeks since first week start
            weeks_since_first = ((time - first_week_start_time) / (7 * 86_400)).to_i
            floored_weeks = (weeks_since_first / offset) * offset

            result_date = first_week_start + (floored_weeks * 7)
            Time.new(result_date.year, result_date.month, result_date.day, 0, 0, 0, time.utc_offset)
          end

        when :month
          # Floor to month segment boundary (from start of year)
          months_from_jan = time.month - 1 # 0-indexed
          floored_months = (months_from_jan / offset) * offset
          Time.new(time.year, floored_months + 1, 1, 0, 0, 0, time.utc_offset)

        when :quarter
          # Floor to quarter segment boundary
          current_quarter = ((time.month - 1) / 3) # 0-indexed quarters
          floored_quarters = (current_quarter / offset) * offset
          quarter_start_month = (floored_quarters * 3) + 1
          Time.new(time.year, quarter_start_month, 1, 0, 0, 0, time.utc_offset)

        when :year
          # Floor to year segment boundary
          floored_years = (time.year / offset) * offset
          Time.new(floored_years, 1, 1, 0, 0, 0, time.utc_offset)
        end
      end

      private

      def add_one_month(time) # rubocop:disable Metrics/AbcSize
        next_month = time.month == 12 ? 1 : time.month + 1
        next_year = time.month == 12 ? time.year + 1 : time.year

        # Handle the case where the day doesn't exist in the next month (e.g., Jan 31 -> Feb 31)
        max_day = days_in_month(next_year, next_month)
        day = [time.day, max_day].min

        Time.new(next_year, next_month, day, time.hour, time.min, time.sec, config.tz.utc_offset)
      end

      def days_in_month(year, month)
        Date.new(year, month, -1).day
      end
    end
  end
end
