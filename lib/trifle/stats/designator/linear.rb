# frozen_string_literal: true

module Trifle
  module Stats
    class Designator
      class Linear
        attr_reader :min, :max, :step

        def initialize(min:, max:, step:)
          @min = min
          @max = max
          @step = step.to_i
        end

        def designate(value:) # rubocop:disable Metrics/AbcSize
          return min.to_s if value <= min
          return "#{max}+" if value > max

          (value.ceil / step * step + ((value.ceil % step).zero? ? 0 : step)).to_s
        end
      end
    end
  end
end
