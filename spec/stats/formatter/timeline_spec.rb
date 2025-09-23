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
        { 'count' => 8,  'errors' => 1, 'stats' => { 'requests' => 80,  'responses' => 78 } },
        { 'count' => 12, 'errors' => 0, 'stats' => { 'requests' => 120, 'responses' => 120 } }
      ]
    }
  end
  let(:series) { Trifle::Stats::Series.new(series_data) }

  describe '#format' do
    context 'with explicit path' do
      it 'returns timeline entries keyed by full path' do
        result = series.format.timeline(path: 'count')

        expect(result).to eq(
          'count' => [
            [Time.parse('2023-01-01 10:00:00'), 10.0],
            [Time.parse('2023-01-01 11:00:00'), 15.0],
            [Time.parse('2023-01-01 12:00:00'), 8.0],
            [Time.parse('2023-01-01 13:00:00'), 12.0]
          ]
        )
      end

      it 'supports nested paths' do
        result = series.format.timeline(path: 'stats.requests')

        expect(result).to eq(
          'stats.requests' => [
            [Time.parse('2023-01-01 10:00:00'), 100.0],
            [Time.parse('2023-01-01 11:00:00'), 150.0],
            [Time.parse('2023-01-01 12:00:00'), 80.0],
            [Time.parse('2023-01-01 13:00:00'), 120.0]
          ]
        )
      end
    end

    context 'with wildcards' do
      it 'fans out nested paths under a wildcard' do
        result = series.format.timeline(path: 'stats.*')

        expect(result.keys.sort).to eq(%w[stats.requests stats.responses])
        expect(result['stats.requests'].map(&:last)).to eq([100.0, 150.0, 80.0, 120.0])
        expect(result['stats.responses'].map(&:last)).to eq([95.0, 140.0, 78.0, 120.0])
      end

      it 'aggregates only the requested key when wildcard is replaced with specific segment' do
        result = series.format.timeline(path: 'stats.responses')

        expect(result.keys).to eq(['stats.responses'])
        expect(result['stats.responses'].map(&:last)).to eq([95.0, 140.0, 78.0, 120.0])
      end
    end

    context 'with slicing' do
      it 'returns slice arrays for multi-slice requests' do
        result = series.format.timeline(path: 'count', slices: 2)

        expect(result).to eq(
          'count' => [
            [
              [Time.parse('2023-01-01 10:00:00'), 10.0],
              [Time.parse('2023-01-01 11:00:00'), 15.0]
            ],
            [
              [Time.parse('2023-01-01 12:00:00'), 8.0],
              [Time.parse('2023-01-01 13:00:00'), 12.0]
            ]
          ]
        )
      end

      it 'drops remainder entries from the front like the Elixir implementation' do
        larger_series = Trifle::Stats::Series.new(
          at: (1..6).map { |i| Time.parse("2023-01-01 #{9 + i}:00:00") },
          values: (1..6).map { |i| { 'count' => i * 10 } }
        )

        result = larger_series.format.timeline(path: 'count', slices: 4)

        expect(result['count']).to eq(
          [
            [[Time.parse('2023-01-01 12:00:00'), 30.0]],
            [[Time.parse('2023-01-01 13:00:00'), 40.0]],
            [[Time.parse('2023-01-01 14:00:00'), 50.0]],
            [[Time.parse('2023-01-01 15:00:00'), 60.0]]
          ]
        )
      end
    end

    context 'with blocks' do
      it 'applies transformation block per entry' do
        result = series.format.timeline(path: 'count') do |at, value|
          [at.strftime('%H:%M'), value * 2]
        end

        expect(result).to eq(
          'count' => [
            ['10:00', 20],
            ['11:00', 30],
            ['12:00', 16],
            ['13:00', 24]
          ]
        )
      end

      it 'applies transformation blocks alongside slicing' do
        result = series.format.timeline(path: 'count', slices: 2) do |at, value|
          [at.hour, value + 1]
        end

        expect(result['count']).to eq(
          [
            [[10, 11], [11, 16]],
            [[12, 9], [13, 13]]
          ]
        )
      end
    end

    context 'with missing data' do
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

      it 'coerces nils to zero when the value is missing' do
        result = sparse_series.format.timeline(path: 'count')

        expect(result['count'].map(&:last)).to eq([10.0, 0.0, 8.0])
      end

      it 'yields raw nil to blocks allowing custom handling' do
        result = sparse_series.format.timeline(path: 'count') do |at, value|
          [at.hour, value.nil? ? 999 : value]
        end

        expect(result['count']).to eq([[10, 10], [11, 999], [12, 8]])
      end
    end

    context 'with empty inputs' do
      it 'returns an empty hash for empty series' do
        empty_series = Trifle::Stats::Series.new(at: [], values: [])
        expect(empty_series.format.timeline(path: 'count')).to eq({})
      end

      it 'returns zero-filled entries for missing paths' do
        result = series.format.timeline(path: 'nonexistent')

        expect(result['nonexistent'].map(&:last)).to eq([0.0, 0.0, 0.0, 0.0])
      end
    end
  end

  describe 'Series integration' do
    it 'registers timeline formatter on Series' do
      expect(series.format).to respond_to(:timeline)
    end

    it 'keeps time ordering inside each returned timeline' do
      entries = series.format.timeline(path: 'count')['count']
      expect(entries.map(&:first)).to eq(entries.map(&:first).sort)
    end
  end
end
