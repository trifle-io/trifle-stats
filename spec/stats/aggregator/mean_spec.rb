require 'time'

RSpec.describe Trifle::Stats::Aggregator::Mean do
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
        { 'count' => 20, 'errors' => 4, 'stats' => { 'requests' => 200, 'responses' => 190 } },
        { 'count' => 8, 'errors' => 1, 'stats' => { 'requests' => 80, 'responses' => 78 } },
        { 'count' => 12, 'errors' => 0, 'stats' => { 'requests' => 120, 'responses' => 120 } }
      ]
    }
  end
  let(:series) { Trifle::Stats::Series.new(series_data) }

  describe '#aggregate' do
    context 'with simple path' do
      it 'calculates average of all values for given path' do
        result = series.aggregate.mean(path: 'count')

        expect(result).to eq([12.5]) # (10 + 20 + 8 + 12) / 4 = 50 / 4 = 12.5
      end

      it 'handles integer division correctly' do
        result = series.aggregate.mean(path: 'errors')

        expect(result).to eq([1.75]) # (2 + 4 + 1 + 0) / 4 = 7 / 4 = 1.75
      end
    end

    context 'with nested path' do
      it 'calculates average of nested values using dot notation' do
        result = series.aggregate.mean(path: 'stats.requests')

        expect(result).to eq([125]) # (100 + 200 + 80 + 120) / 4 = 500 / 4 = 125
      end

      it 'handles nested paths with different structure' do
        result = series.aggregate.mean(path: 'stats.responses')

        expect(result).to eq([120.75]) # (95 + 190 + 78 + 120) / 4 = 483 / 4 = 120.75
      end
    end

    context 'with slicing' do
      it 'calculates average for each slice separately' do
        result = series.aggregate.mean(path: 'count', slices: 2)

        expect(result).to eq([15, 10]) # [(10+20)/2, (8+12)/2] = [15, 10]
      end

      it 'handles slicing with 4 slices (each value separate)' do
        result = series.aggregate.mean(path: 'count', slices: 4)

        expect(result).to eq([10, 20, 8, 12]) # Each slice has one value
      end

      it 'handles slicing with nested paths' do
        result = series.aggregate.mean(path: 'stats.requests', slices: 2)

        expect(result).to eq([150, 100]) # [(100+200)/2, (80+120)/2] = [150, 100]
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

      it 'ignores nil values and averages existing ones' do
        result = sparse_series.aggregate.mean(path: 'count')

        expect(result.first.round(2)).to eq(12.67) # (10 + 8 + 20) / 3 = 38 / 3 = 12.666...
      end

      it 'handles slicing with missing values' do
        result = sparse_series.aggregate.mean(path: 'count', slices: 2)

        expect(result).to eq([10, 14]) # [10/1, (8+20)/2] = [10, 14]
      end
    end

    context 'with empty series' do
      let(:empty_series_data) { { at: [], values: [] } }
      let(:empty_series) { Trifle::Stats::Series.new(empty_series_data) }

      it 'returns empty array for empty series' do
        result = empty_series.aggregate.mean(path: 'count')

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

      it 'returns zero when all values are nil (division by zero protection)' do
        result = nil_series.aggregate.mean(path: 'count')

        expect(result).to eq([0]) # count.zero? ? 0 : sum / count
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
            { 'count' => 6 }
          ]
        }
      end
      let(:zero_series) { Trifle::Stats::Series.new(zero_series_data) }

      it 'includes zero values in average calculation' do
        result = zero_series.aggregate.mean(path: 'count')

        expect(result).to eq([2]) # (0 + 0 + 6) / 3 = 6 / 3 = 2
      end
    end

    context 'with non-existent path' do
      it 'returns zero for completely missing path (division by zero protection)' do
        result = series.aggregate.mean(path: 'nonexistent')

        expect(result).to eq([0]) # All nils, compact removes them, empty count triggers zero protection
      end

      it 'returns zero for missing nested path' do
        result = series.aggregate.mean(path: 'stats.missing')

        expect(result).to eq([0])
      end
    end

    context 'with complex slicing scenarios' do
      let(:larger_series_data) do
        {
          at: (1..9).map { |i| Time.parse("2023-01-01 #{9+i}:00:00") },
          values: (1..9).map { |i| { 'count' => i * 10 } }
        }
      end
      let(:larger_series) { Trifle::Stats::Series.new(larger_series_data) }

      it 'handles slicing with 3 slices' do
        result = larger_series.aggregate.mean(path: 'count', slices: 3)

        # With 9 values and 3 slices: all 9 values used, 3 values per slice
        # Values: [10, 20, 30, 40, 50, 60, 70, 80, 90]
        # Slices: [(10+20+30)/3], [(40+50+60)/3], [(70+80+90)/3]
        expect(result).to eq([20, 50, 80]) # [60/3, 150/3, 240/3]
      end

      it 'handles uneven slicing' do
        result = larger_series.aggregate.mean(path: 'count', slices: 4)

        # With 9 values and 4 slices: takes last 8 values, 2 values per slice
        # Values: [20, 30, 40, 50, 60, 70, 80, 90]
        # Slices: [(20+30)/2], [(40+50)/2], [(60+70)/2], [(80+90)/2]
        expect(result).to eq([25, 45, 65, 85])
      end
    end
  end

  describe 'integration with Series' do
    it 'is properly registered as mean aggregator' do
      expect(series.aggregate).to respond_to(:mean)
    end

    it 'can be chained with other operations' do
      averaged = series.aggregate.mean(path: 'count')
      expect(averaged).to be_an(Array)
      expect(averaged.first).to be_a(Numeric)
    end

    it 'provides different results than sum for same data' do
      sum_result = series.aggregate.sum(path: 'count')
      mean_result = series.aggregate.mean(path: 'count')

      expect(sum_result).to eq([50]) # 10 + 20 + 8 + 12
      expect(mean_result).to eq([12.5]) # 50 / 4
      expect(sum_result).not_to eq(mean_result)
    end
  end
end
