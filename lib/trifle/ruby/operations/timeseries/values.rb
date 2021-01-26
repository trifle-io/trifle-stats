# frozen_string_literal: true

module Trifle
  module Ruby
    module Operations
      module Timeseries
        class Values < Operation
          def initialize(key:, from:, to:, range:, configuration: nil)
            @configuration = configuration
            @key = key
            @from = from
            @to = to
            @range = range
            super
          end

          def timeline
            Nocturnal.timeline(from: @from, to: @to, range: @range)
          end

          def perform
            timeline.map do |at|
              config.driver.get(
                key: [@key, @range, at.to_i].join(config.separator)
              )
            end
          end
        end
      end
    end
  end
end
