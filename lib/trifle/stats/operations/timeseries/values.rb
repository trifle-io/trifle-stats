# frozen_string_literal: true

module Trifle
  module Stats
    module Operations
      module Timeseries
        class Values
          attr_reader :key, :granularity

          def initialize(**keywords)
            @key = keywords.fetch(:key)
            @from = keywords.fetch(:from)
            @to = keywords.fetch(:to)
            @granularity = keywords.fetch(:granularity)
            @config = keywords[:config]
            @skip_blanks = keywords[:skip_blanks]
          end

          def config
            @config || Trifle::Stats.default
          end

          def timeline
            @timeline ||= Nocturnal.timeline(from: @from, to: @to, granularity: granularity)
          end

          def data
            @data ||= config.driver.get(
              keys: timeline.map do |at|
                Nocturnal::Key.new(key: key, granularity: granularity, at: at)
              end
            )
          end

          def clean_values
            timeline.each_with_object({ at: [], values: [] }).with_index do |(_at, res), idx|
              next if data[idx].empty?

              res[:at] << timeline[idx]
              res[:values] << data[idx]
            end
          end

          def values
            {
              at: timeline,
              values: data
            }
          end

          def perform
            @skip_blanks ? clean_values : values
          end
        end
      end
    end
  end
end
