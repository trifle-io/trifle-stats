require 'time'

RSpec.describe Trifle::Stats::Aggregator::Max do
  let(:series_data) do
    {
      at: [
        Time.parse('2023-01-01 10:00:00'),
        Time.parse('2023-01-01 11:00:00'),
        Time.parse('2023-01-01 12:00:00'),
        Time.parse('2023-01-01 13:00:00')
      ],
      values: [
        { 'count' => 10, 'errors' => 2, 'stats' => { 'requests' => 100, 'responses' => 95 } },
        { 'count' => 25, 'errors' => 8, 'stats' => { 'requests' => 250, 'responses' => 240 } },
        { 'count' => 5, 'errors' => 1, 'stats' => { 'requests' => 50, 'responses' => 48 } },
        { 'count' => 15, 'errors' => 0, 'stats' => { 'requests' => 150, 'responses' => 150 } }
      ]
    }
  end
  let(:series) { Trifle::Stats::Series.new(series_data) }

  describe '#aggregate' do
    context 'with simple path' do
      it 'finds maximum value for given path' do
        result = series.aggregate.max(path: 'count')

        expect(result).to eq([25]) # max(10, 25, 5, 15) = 25
      end

      it 'handles finding maximum with zero values' do
        result = series.aggregate.max(path: 'errors')

        expect(result).to eq([8]) # max(2, 8, 1, 0) = 8
      end
    end

    context 'with nested path' do
      it 'finds maximum of nested values using dot notation' do
        result = series.aggregate.max(path: 'stats.requests')

        expect(result).to eq([250]) # max(100, 250, 50, 150) = 250
      end

      it 'handles nested paths with different structure' do
        result = series.aggregate.max(path: 'stats.responses')

        expect(result).to eq([240]) # max(95, 240, 48, 150) = 240
      end
    end

    context 'with slicing' do
      it 'finds maximum for each slice separately' do
        result = series.aggregate.max(path: 'count', slices: 2)

        expect(result).to eq([25, 15]) # [max(10, 25), max(5, 15)] = [25, 15]
      end

      it 'handles slicing with 4 slices (each value separate)' do
        result = series.aggregate.max(path: 'count', slices: 4)

        expect(result).to eq([10, 25, 5, 15]) # Each slice has one value
      end

      it 'handles slicing with nested paths' do
        result = series.aggregate.max(path: 'stats.requests', slices: 2)

        expect(result).to eq([250, 150]) # [max(100, 250), max(50, 150)] = [250, 150]
      end
    end

    context 'with missing values' do
      let(:sparse_series_data) do
        {
          at: [
            Time.parse('2023-01-01 10:00:00'),
            Time.parse('2023-01-01 11:00:00'),
            Time.parse('2023-01-01 12:00:00'),
            Time.parse('2023-01-01 13:00:00')
          ],
          values: [
            { 'count' => 10 },
            { 'other' => 5 },
            { 'count' => 8 },
            { 'count' => 20 }
          ]
        }
      end
      let(:sparse_series) { Trifle::Stats::Series.new(sparse_series_data) }

      it 'ignores nil values and finds maximum of existing ones' do
        result = sparse_series.aggregate.max(path: 'count')

        expect(result).to eq([20]) # max(10, 8, 20) = 20 (nil ignored)
      end

      it 'handles slicing with missing values' do
        result = sparse_series.aggregate.max(path: 'count', slices: 2)

        expect(result).to eq([10, 20]) # [max(10), max(8, 20)] = [10, 20]
      end
    end

    context 'with negative values' do
      let(:negative_series_data) do
        {
          at: [
            Time.parse('2023-01-01 10:00:00'),
            Time.parse('2023-01-01 11:00:00'),
            Time.parse('2023-01-01 12:00:00')
          ],
          values: [
            { 'balance' => -100 },
            { 'balance' => -50 },
            { 'balance' => -25 }
          ]
        }
      end
      let(:negative_series) { Trifle::Stats::Series.new(negative_series_data) }

      it 'correctly finds maximum with negative values' do
        result = negative_series.aggregate.max(path: 'balance')

        expect(result).to eq([-25]) # max(-100, -50, -25) = -25
      end
    end

    context 'with mixed positive and negative values' do
      let(:mixed_series_data) do
        {
          at: [
            Time.parse('2023-01-01 10:00:00'),
            Time.parse('2023-01-01 11:00:00'),
            Time.parse('2023-01-01 12:00:00')
          ],
          values: [
            { 'balance' => -100 },
            { 'balance' => 50 },
            { 'balance' => -25 }
          ]
        }
      end
      let(:mixed_series) { Trifle::Stats::Series.new(mixed_series_data) }

      it 'correctly finds maximum with mixed values' do
        result = mixed_series.aggregate.max(path: 'balance')

        expect(result).to eq([50]) # max(-100, 50, -25) = 50
      end
    end

    context 'with empty series' do
      let(:empty_series_data) { { at: [], values: [] } }
      let(:empty_series) { Trifle::Stats::Series.new(empty_series_data) }

      it 'returns empty array for empty series' do
        result = empty_series.aggregate.max(path: 'count')

        expect(result).to eq([])
      end
    end

    context 'with all nil values' do
      let(:nil_series_data) do
        {
          at: [
            Time.parse('2023-01-01 10:00:00'),
            Time.parse('2023-01-01 11:00:00')
          ],
          values: [
            { 'other' => 5 },
            { 'different' => 10 }
          ]
        }
      end
      let(:nil_series) { Trifle::Stats::Series.new(nil_series_data) }

      it 'returns nil when all values are nil for the path' do
        result = nil_series.aggregate.max(path: 'count')

        expect(result).to eq([nil]) # max of empty array after compact is nil
      end
    end

    context 'with single value' do
      let(:single_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'count' => 42 }]
        }
      end
      let(:single_series) { Trifle::Stats::Series.new(single_series_data) }

      it 'returns the single value as maximum' do
        result = single_series.aggregate.max(path: 'count')

        expect(result).to eq([42])
      end
    end

    context 'with identical values' do
      let(:identical_series_data) do
        {
          at: [
            Time.parse('2023-01-01 10:00:00'),
            Time.parse('2023-01-01 11:00:00'),
            Time.parse('2023-01-01 12:00:00')
          ],
          values: [
            { 'count' => 100 },
            { 'count' => 100 },
            { 'count' => 100 }
          ]
        }
      end
      let(:identical_series) { Trifle::Stats::Series.new(identical_series_data) }

      it 'returns the common value as maximum' do
        result = identical_series.aggregate.max(path: 'count')

        expect(result).to eq([100])
      end
    end

    context 'with zero values' do
      let(:zero_series_data) do
        {
          at: [
            Time.parse('2023-01-01 10:00:00'),
            Time.parse('2023-01-01 11:00:00'),
            Time.parse('2023-01-01 12:00:00')
          ],
          values: [
            { 'count' => 0 },
            { 'count' => 0 },
            { 'count' => 0 }
          ]
        }
      end
      let(:zero_series) { Trifle::Stats::Series.new(zero_series_data) }

      it 'correctly handles all zero values' do
        result = zero_series.aggregate.max(path: 'count')

        expect(result).to eq([0]) # max(0, 0, 0) = 0
      end
    end

    context 'with non-existent path' do
      it 'returns nil for completely missing path' do
        result = series.aggregate.max(path: 'nonexistent')

        expect(result).to eq([nil]) # All nils, compact removes them, max of empty array is nil
      end

      it 'returns nil for missing nested path' do
        result = series.aggregate.max(path: 'stats.missing')

        expect(result).to eq([nil])
      end
    end

    context 'with complex slicing scenarios' do
      let(:larger_series_data) do
        {
          at: (1..10).map { |i| Time.parse("2023-01-01 #{9+i}:00:00") },
          values: [100, 50, 200, 25, 150, 75, 300, 10, 250, 125].map { |val| { 'count' => val } }
        }
      end
      let(:larger_series) { Trifle::Stats::Series.new(larger_series_data) }

      it 'handles slicing with 5 slices' do
        result = larger_series.aggregate.max(path: 'count', slices: 5)

        # Each slice has 2 values
        # [100, 50], [200, 25], [150, 75], [300, 10], [250, 125]
        expect(result).to eq([100, 200, 150, 300, 250])
      end

      it 'handles uneven slicing' do
        result = larger_series.aggregate.max(path: 'count', slices: 3)

        # With 10 values and 3 slices: takes last 9 values, 3 values per slice
        # Values: [50, 200, 25, 150, 75, 300, 10, 250, 125]
        # Slices: [50, 200, 25], [150, 75, 300], [10, 250, 125]
        expect(result).to eq([200, 300, 250])
      end
    end
  end

  describe 'integration with Series' do
    it 'is properly registered as max aggregator' do
      expect(series.aggregate).to respond_to(:max)
    end

    it 'can be chained with other operations' do
      maximum = series.aggregate.max(path: 'count')
      expect(maximum).to be_an(Array)
      expect(maximum.first).to be_a(Numeric)
    end

    it 'provides different results than sum, mean, and min for same data' do
      sum_result = series.aggregate.sum(path: 'count')
      mean_result = series.aggregate.mean(path: 'count')
      min_result = series.aggregate.min(path: 'count')
      max_result = series.aggregate.max(path: 'count')

      expect(sum_result).to eq([55]) # 10 + 25 + 5 + 15
      expect(mean_result).to eq([13.75]) # 55 / 4 = 13.75
      expect(min_result).to eq([5])  # min(10, 25, 5, 15)
      expect(max_result).to eq([25]) # max(10, 25, 5, 15)
      
      expect([sum_result, mean_result, min_result, max_result].uniq.length).to eq(4) # All different
    end

    it 'max is always >= min for the same data' do
      min_result = series.aggregate.min(path: 'count').first
      max_result = series.aggregate.max(path: 'count').first

      expect(max_result).to be >= min_result
    end
  end
end