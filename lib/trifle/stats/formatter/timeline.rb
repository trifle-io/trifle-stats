# frozen_string_literal: true

module Trifle
  module Stats
    class Formatter
      class Timeline
        Trifle::Stats::Series.register_formatter(:timeline, self)

        def format(series:, path:)
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
