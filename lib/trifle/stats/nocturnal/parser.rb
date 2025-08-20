# frozen_string_literal: true

module Trifle
  module Stats
    class Nocturnal
      class Parser
        attr_reader :string, :offset, :unit

        def initialize(string)
          @string = string

          parse
        end

        def valid?
          !!(offset && unit)
        end

        private

        def parse
          match = string.match(/\A(\d+)([a-z]+)\z/)
          return unless match

          range = Trifle::Stats::Nocturnal::UNIT_MAP[match[2]]
          return unless range

          @offset = match[1].to_i
          @unit = range
        end
      end
    end
  end
end
