# frozen_string_literal: true

module Trifle
  module Stats
    module Operations
      module Status
        class Scan
          attr_reader :key

          def initialize(**keywords)
            @key = keywords.fetch(:key)
            @config = keywords[:config]
          end

          def config
            @config || Trifle::Stats.default
          end

          def data
            @data ||= config.driver.scan(
              key: Nocturnal::Key.new(key: key)
            )
          end

          def perform
            {
              at: data.first,
              values: data.last
            }
          end
        end
      end
    end
  end
end
