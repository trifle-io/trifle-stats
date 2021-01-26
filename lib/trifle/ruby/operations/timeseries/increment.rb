# frozen_string_literal: true

module Trifle
  module Ruby
    module Operations
      module Timeseries
        class Increment < Operation
          def perform
            config.ranges.map do |range|
              at = Nocturnal.new(@at).send("beginning_of_#{range}")
              config.driver.inc(
                key: [@key, range, at.to_i].join(config.separator),
                **@values
              )
            end
          end
        end
      end
    end
  end
end
