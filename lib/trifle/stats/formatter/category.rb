# frozen_string_literal: true

module Trifle
  module Stats
    class Formatter
      class Category
        Trifle::Stats::Series.register_formatter(:category, self)

        def format(series:, path:)
          keys = path.split('.')
          series[:at].each_with_object(Hash.new(0)).with_index do |(_at, map), i|
            series[:values][i].dig(*keys).each do |key, value|
              k, v = block_given? ? yield(key, value) : [key.to_s, value.to_f]
              map[k] += v
            end
          end
        end
      end
    end
  end
end
