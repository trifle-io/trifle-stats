# frozen_string_literal: true

module Trifle
  module Stats
    module Operations
      module Timeseries
        class Values
          attr_reader :key, :range

          def initialize(**keywords)
            @key = keywords.fetch(:key)
            @from = keywords.fetch(:from)
            @to = keywords.fetch(:to)
            @range = keywords.fetch(:range)
            @config = keywords[:config]
          end

          def config
            @config || Trifle::Stats.default
          end

          def timeline
            Nocturnal.timeline(from: @from, to: @to, range: range)
          end

          def perform
            timeline.map do |at|
              {
                at => config.driver.get(
                  key: [key, range, at.to_i]
                )
              }
            end
          end
        end
      end
    end
  end
end
