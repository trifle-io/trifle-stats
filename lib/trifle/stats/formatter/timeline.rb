# frozen_string_literal: true

module Trifle
  module Stats
    class Formatter
      class Timeline
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

        def format
          series[:at].map.with_index do |at, i|
            value = series[:values][i].dig(*keys)
            block_given? ? yield(at, value) : [at, value.to_f]
          end
        end
      end
    end
  end
end
