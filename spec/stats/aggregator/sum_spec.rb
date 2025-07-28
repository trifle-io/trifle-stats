require 'time'

RSpec.describe Trifle::Stats::Aggregator::Sum do
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
        { 'count' => 15, 'errors' => 3, 'stats' => { 'requests' => 150, 'responses' => 140 } },
        { 'count' => 8, 'errors' => 1, 'stats' => { 'requests' => 80, 'responses' => 78 } },
        { 'count' => 12, 'errors' => 0, 'stats' => { 'requests' => 120, 'responses' => 120 } }
      ]
    }
  end
  let(:series) { Trifle::Stats::Series.new(series_data) }

  describe '#aggregate' do
    context 'with simple path' do
      it 'sums all values for given path' do
        result = series.aggregate.sum(path: 'count')

        expect(result).to eq([45]) # 10 + 15 + 8 + 12
      end

      it 'handles zero values correctly' do
        result = series.aggregate.sum(path: 'errors')

        expect(result).to eq([6]) # 2 + 3 + 1 + 0
      end
    end

    context 'with nested path' do
      it 'sums nested values using dot notation' do
        result = series.aggregate.sum(path: 'stats.requests')

        expect(result).to eq([450]) # 100 + 150 + 80 + 120
      end

      it 'handles nested paths with different structure' do
        result = series.aggregate.sum(path: 'stats.responses')

        expect(result).to eq([433]) # 95 + 140 + 78 + 120
      end
    end

    context 'with slicing' do
      it 'slices data into specified number of slices' do
        result = series.aggregate.sum(path: 'count', slices: 2)

        expect(result).to eq([25, 20]) # [10+15, 8+12]
      end

      it 'handles slicing with 4 slices (each value separate)' do
        result = series.aggregate.sum(path: 'count', slices: 4)

        expect(result).to eq([10, 15, 8, 12])
      end

      it 'handles slicing with nested paths' do
        result = series.aggregate.sum(path: 'stats.requests', slices: 2)

        expect(result).to eq([250, 200]) # [100+150, 80+120]
      end
    end

    context 'with missing values' do
      let(:sparse_series_data) do
        {
          at: [
            Time.parse('2023-01-01 10:00:00'),
            Time.parse('2023-01-01 11:00:00'),
            Time.parse('2023-01-01 12:00:00')
          ],
          values: [
            { 'count' => 10 },
            { 'other' => 5 },
            { 'count' => 8 }
          ]
        }
      end
      let(:sparse_series) { Trifle::Stats::Series.new(sparse_series_data) }

      it 'ignores nil values and sums existing ones' do
        result = sparse_series.aggregate.sum(path: 'count')

        expect(result).to eq([18]) # 10 + nil (ignored) + 8
      end
    end

    context 'with empty series' do
      let(:empty_series_data) { { at: [], values: [] } }
      let(:empty_series) { Trifle::Stats::Series.new(empty_series_data) }

      it 'returns empty array for empty series' do
        result = empty_series.aggregate.sum(path: 'count')

        expect(result).to eq([])
      end
    end

    context 'with non-existent path' do
      it 'returns zero for completely missing path' do
        result = series.aggregate.sum(path: 'nonexistent')

        expect(result).to eq([0]) # All nils, compact removes them, sum of empty array is 0
      end

      it 'returns zero for missing nested path' do
        result = series.aggregate.sum(path: 'stats.missing')

        expect(result).to eq([0])
      end
    end

    context 'with complex slicing scenarios' do
      let(:larger_series_data) do
        {
          at: (1..10).map { |i| Time.parse("2023-01-01 #{9+i}:00:00") },
          values: (1..10).map { |i| { 'count' => i * 10 } }
        }
      end
      let(:larger_series) { Trifle::Stats::Series.new(larger_series_data) }

      it 'handles slicing with 5 slices' do
        result = larger_series.aggregate.sum(path: 'count', slices: 5)

        # With 10 values and 5 slices: each slice has 2 values
        # Values: [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
        # Slices: [10+20], [30+40], [50+60], [70+80], [90+100]
        expect(result).to eq([30, 70, 110, 150, 190])
      end

      it 'handles uneven slicing' do
        result = larger_series.aggregate.sum(path: 'count', slices: 3)

        # With 10 values and 3 slices: takes last 9 values, 3 values per slice
        # Values: [20, 30, 40, 50, 60, 70, 80, 90, 100]
        # Slices: [20+30+40], [50+60+70], [80+90+100]
        expect(result).to eq([90, 180, 270])
      end
    end
  end

  describe 'integration with Series' do
    it 'is properly registered as sum aggregator' do
      expect(series.aggregate).to respond_to(:sum)
    end

    it 'can be chained with other operations' do
      # Test that the aggregator can be used as part of a larger workflow
      summed = series.aggregate.sum(path: 'count')
      expect(summed).to be_an(Array)
      expect(summed.first).to be_a(Numeric)
    end
  end
end