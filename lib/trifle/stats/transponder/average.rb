# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class Average
        include Trifle::Stats::Mixins::Packer

        attr_reader :sum, :count

        def initialize(sum: 'sum', count: 'count')
          @sum = sum
          @count = count
        end

        def transpond(series:, path:)
          keys = path.split('.')
          series[:values] = series[:values].map do |data|
            signal = {
              "#{path}.average" => data.dig(*keys, sum) / data.dig(*keys, count)
            }
            self.class.deep_merge(data, self.class.unpack(hash: signal))
          end
          series
        end
      end
    end
  end
end
