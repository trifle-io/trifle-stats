# frozen_string_literal: true

module Trifle
  module Stats
    class Aggregator
      class Sum
        include Trifle::Stats::Mixins::Packer

        attr_reader :series, :path

        def initialize(series:, path:)
          @series = series
          @series[:values] = self.class.normalize(@series[:values])
          @path = path
        end

        def keys
          @keys ||= path.split('.')
        end

        def aggregate
          result = series[:values].map do |data|
            data.dig(*keys).to_f
          end
          result.sum
        end
      end
    end
  end
end
