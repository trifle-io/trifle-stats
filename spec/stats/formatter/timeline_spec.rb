require 'time'

RSpec.describe Trifle::Stats::Formatter::Timeline do
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

  describe '#format' do
    context 'with simple path' do
      it 'formats simple path as timeline array' do
        result = series.format.timeline(path: 'count')

        expect(result).to eq([[
          [Time.parse('2023-01-01 10:00:00'), 10.0],
          [Time.parse('2023-01-01 11:00:00'), 15.0],
          [Time.parse('2023-01-01 12:00:00'), 8.0],
          [Time.parse('2023-01-01 13:00:00'), 12.0]
        ]])
      end

      it 'converts numeric values to floats' do
        result = series.format.timeline(path: 'errors')

        expect(result).to eq([[
          [Time.parse('2023-01-01 10:00:00'), 2.0],
          [Time.parse('2023-01-01 11:00:00'), 3.0],
          [Time.parse('2023-01-01 12:00:00'), 1.0],
          [Time.parse('2023-01-01 13:00:00'), 0.0]
        ]])
      end
    end

    context 'with nested path' do
      it 'formats nested path using dot notation' do
        result = series.format.timeline(path: 'stats.requests')

        expect(result).to eq([[
          [Time.parse('2023-01-01 10:00:00'), 100.0],
          [Time.parse('2023-01-01 11:00:00'), 150.0],
          [Time.parse('2023-01-01 12:00:00'), 80.0],
          [Time.parse('2023-01-01 13:00:00'), 120.0]
        ]])
      end

      it 'handles nested paths with different values' do
        result = series.format.timeline(path: 'stats.responses')

        expect(result).to eq([[
          [Time.parse('2023-01-01 10:00:00'), 95.0],
          [Time.parse('2023-01-01 11:00:00'), 140.0],
          [Time.parse('2023-01-01 12:00:00'), 78.0],
          [Time.parse('2023-01-01 13:00:00'), 120.0]
        ]])
      end
    end

    context 'with slicing' do
      it 'slices data into specified number of slices' do
        result = series.format.timeline(path: 'count', slices: 2)

        expect(result).to eq([
          [
            [Time.parse('2023-01-01 10:00:00'), 10.0],
            [Time.parse('2023-01-01 11:00:00'), 15.0]
          ],
          [
            [Time.parse('2023-01-01 12:00:00'), 8.0],
            [Time.parse('2023-01-01 13:00:00'), 12.0]
          ]
        ])
      end

      it 'handles slicing with 4 slices (each value separate)' do
        result = series.format.timeline(path: 'count', slices: 4)

        expect(result).to eq([
          [[Time.parse('2023-01-01 10:00:00'), 10.0]],
          [[Time.parse('2023-01-01 11:00:00'), 15.0]],
          [[Time.parse('2023-01-01 12:00:00'), 8.0]],
          [[Time.parse('2023-01-01 13:00:00'), 12.0]]
        ])
      end

      it 'handles slicing with nested paths' do
        result = series.format.timeline(path: 'stats.requests', slices: 2)

        expect(result).to eq([
          [
            [Time.parse('2023-01-01 10:00:00'), 100.0],
            [Time.parse('2023-01-01 11:00:00'), 150.0]
          ],
          [
            [Time.parse('2023-01-01 12:00:00'), 80.0],
            [Time.parse('2023-01-01 13:00:00'), 120.0]
          ]
        ])
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

      it 'handles nil values gracefully' do
        result = sparse_series.format.timeline(path: 'count')

        expect(result).to eq([[
          [Time.parse('2023-01-01 10:00:00'), 10.0],
          [Time.parse('2023-01-01 11:00:00'), 0.0], # nil.to_f = 0.0
          [Time.parse('2023-01-01 12:00:00'), 8.0]
        ]])
      end
    end

    context 'with empty series' do
      let(:empty_series_data) { { at: [], values: [] } }
      let(:empty_series) { Trifle::Stats::Series.new(empty_series_data) }

      it 'returns empty array for empty series' do
        result = empty_series.format.timeline(path: 'count')

        expect(result).to eq([])
      end
    end

    context 'with non-existent path' do
      it 'returns zeros for completely missing path' do
        result = series.format.timeline(path: 'nonexistent')

        expect(result).to eq([[
          [Time.parse('2023-01-01 10:00:00'), 0.0],
          [Time.parse('2023-01-01 11:00:00'), 0.0],
          [Time.parse('2023-01-01 12:00:00'), 0.0],
          [Time.parse('2023-01-01 13:00:00'), 0.0]
        ]])
      end

      it 'returns zeros for missing nested path' do
        result = series.format.timeline(path: 'stats.missing')

        expect(result).to eq([[
          [Time.parse('2023-01-01 10:00:00'), 0.0],
          [Time.parse('2023-01-01 11:00:00'), 0.0],
          [Time.parse('2023-01-01 12:00:00'), 0.0],
          [Time.parse('2023-01-01 13:00:00'), 0.0]
        ]])
      end
    end

    context 'with block transformation' do
      it 'applies block transformation to each value' do
        result = series.format.timeline(path: 'count') do |at, value|
          [at.strftime('%H:%M'), value * 2]
        end

        expect(result).to eq([[
          ['10:00', 20],
          ['11:00', 30],
          ['12:00', 16],
          ['13:00', 24]
        ]])
      end

      it 'applies block transformation with slicing' do
        result = series.format.timeline(path: 'count', slices: 2) do |at, value|
          [at.hour, value + 1]
        end

        expect(result).to eq([
          [[10, 11], [11, 16]],
          [[12, 9], [13, 13]]
        ])
      end

      it 'handles nil values in block transformation' do
        sparse_series_data = {
          at: [Time.parse('2023-01-01 10:00:00'), Time.parse('2023-01-01 11:00:00')],
          values: [{ 'count' => 10 }, { 'other' => 5 }]
        }
        sparse_series = Trifle::Stats::Series.new(sparse_series_data)

        result = sparse_series.format.timeline(path: 'count') do |at, value|
          [at.hour, value || 999] # Custom handling of nil
        end

        expect(result).to eq([[
          [10, 10],
          [11, 999] # Our custom nil handling
        ]])
      end
    end

    context 'with complex slicing scenarios' do
      let(:larger_series_data) do
        {
          at: (1..6).map { |i| Time.parse("2023-01-01 #{9+i}:00:00") },
          values: (1..6).map { |i| { 'count' => i * 10 } }
        }
      end
      let(:larger_series) { Trifle::Stats::Series.new(larger_series_data) }

      it 'handles slicing with 3 slices' do
        result = larger_series.format.timeline(path: 'count', slices: 3)

        expect(result).to eq([
          [
            [Time.parse('2023-01-01 10:00:00'), 10.0],
            [Time.parse('2023-01-01 11:00:00'), 20.0]
          ],
          [
            [Time.parse('2023-01-01 12:00:00'), 30.0],
            [Time.parse('2023-01-01 13:00:00'), 40.0]
          ],
          [
            [Time.parse('2023-01-01 14:00:00'), 50.0],
            [Time.parse('2023-01-01 15:00:00'), 60.0]
          ]
        ])
      end

      it 'handles uneven slicing' do
        result = larger_series.format.timeline(path: 'count', slices: 4)

        # With 6 values and 4 slices: takes last 4 values, 1 value per slice
        expect(result).to eq([
          [[Time.parse('2023-01-01 12:00:00'), 30.0]],
          [[Time.parse('2023-01-01 13:00:00'), 40.0]],
          [[Time.parse('2023-01-01 14:00:00'), 50.0]],
          [[Time.parse('2023-01-01 15:00:00'), 60.0]]
        ])
      end
    end
  end

  describe 'integration with Series' do
    it 'is properly registered as timeline formatter' do
      expect(series.format).to respond_to(:timeline)
    end

    it 'can be chained with other operations' do
      timeline = series.format.timeline(path: 'count')
      expect(timeline).to be_an(Array)
      expect(timeline.first).to be_an(Array)
      expect(timeline.first.first).to be_an(Array)
      expect(timeline.first.first.first).to be_a(Time)
      expect(timeline.first.first.last).to be_a(Float)
    end

    it 'preserves time ordering' do
      timeline = series.format.timeline(path: 'count').first
      times = timeline.map(&:first)
      
      expect(times).to eq(times.sort)
    end
  end
end