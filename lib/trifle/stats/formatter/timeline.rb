# frozen_string_literal: true

module Trifle
  module Stats
    class Formatter
      class Timeline
        include Trifle::Stats::Mixins::Packer

        attr_reader :series

        def initialize(series:)
          @series = series
          @series[:values] = self.class.normalize(@series[:values])
        end

        def format(path:)
          keys = path.split('.')
          series[:at].map.with_index do |at, i|
            value = series[:values][i].dig(*keys)
            block_given? ? yield(at, value) : [at, value.to_f]
          end
        end
      end
    end
  end
end
