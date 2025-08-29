# frozen_string_literal: true

module Trifle
  module Stats
    class Transponder
      class Add
        include Trifle::Stats::Mixins::Packer
        Trifle::Stats::Series.register_transponder(:add, self)

        def transpond(series:, left:, right:, response: 'add') # rubocop:disable Metrics/MethodLength
          left_keys = left.to_s.split('.')
          right_keys = right.to_s.split('.')

          series[:values] = series[:values].map do |data|
            dleft = data.dig(*left_keys)
            dright = data.dig(*right_keys)
            next data unless dleft && dright

            dres = dleft + dright
            signal = {
              response => dres
            }
            self.class.deep_merge(data, self.class.unpack(hash: signal))
          end
          series
        end
      end
    end
  end
end
