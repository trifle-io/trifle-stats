# frozen_string_literal: true

module Trifle
  module Stats
    module Operations
      module Status
        class Beam
          attr_reader :key, :at, :values

          def initialize(**keywords)
            @key = keywords.fetch(:key)
            @at = keywords.fetch(:at)
            @values = keywords.fetch(:values)
            @config = keywords[:config]
          end

          def config
            @config || Trifle::Stats.default
          end

          def perform
            config.driver.ping(
              key: Nocturnal::Key.new(key: key, at: at),
              values: values
            )
          end
        end
      end
    end
  end
end
