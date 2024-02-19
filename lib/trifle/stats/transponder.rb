# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      include Trifle::Stats::Mixins::Packer

      attr_reader :series, :transponders

      def initialize(series:, transponders: [])
        @series = series
        @series[:values] = self.class.normalize(@series[:values])
        @transponders = transponders
      end

      def transpond
        transponders.inject(series) do |ser, transponder|
          transponder.each.inject(ser) do |s, (p, t)|
            t.transpond(series: s, path: p)
          end
        end
      end
    end
  end
end
