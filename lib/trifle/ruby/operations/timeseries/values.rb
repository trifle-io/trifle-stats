# frozen_string_literal: true

module Trifle
  module Ruby
    module Operations
      module Timeseries
        class Values < Operation
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
