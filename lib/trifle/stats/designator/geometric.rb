# frozen_string_literal: true

module Trifle
  module Stats
    class Designator
      class Geometric
        attr_reader :min, :max

        def initialize(min:, max:)
          @min = min.negative? ? 0 : min
          @max = max
        end

        def designate(value:) # rubocop:disable Metrics/AbcSize
          return min.to_f.to_s if value <= min
          return "#{max.to_f}+" if value > max
          return (10**value.floor.to_s.length).to_f.to_s if value > 1
          return 1.0.to_s if value > 0.1 # ugh?

          (1.0 / 10**value.to_s.gsub('0.', '').split(/[1-9]/).first.length).to_s
        end
      end
    end
  end
end
