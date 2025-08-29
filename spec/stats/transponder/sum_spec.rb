require 'time'

RSpec.describe Trifle::Stats::Transponder::Sum do
  let(:series_data) do
    {
      at: [
        Time.parse('2023-01-01 10:00:00'),
        Time.parse('2023-01-01 11:00:00'),
        Time.parse('2023-01-01 12:00:00'),
        Time.parse('2023-01-01 13:00:00')
      ],
      values: [
        { 
          'requests' => { 'items' => [10, 5, 15] },
          'metrics' => { 'scores' => [8, 2, 7, 3] }
        },
        { 
          'requests' => { 'items' => [20, 8, 12] },
          'metrics' => { 'scores' => [9, 4, 6, 1] }
        },
        { 
          'requests' => { 'items' => [5, 15, 10] },
          'metrics' => { 'scores' => [7, 3, 8, 2] }
        },
        { 
          'requests' => { 'items' => [25, 10, 5] },
          'metrics' => { 'scores' => [10, 5, 9, 6] }
        }
      ]
    }
  end
  let(:series) { Trifle::Stats::Series.new(series_data) }

  describe '#transpond' do
    context 'with standard parameters' do
      it 'calculates sum of array values and adds it to the series data' do
        original_series = series.series.dup
        series.transpond.sum(values: 'requests.items', response: 'requests.sum')

        values = series.series[:values]
        expect(values[0]['requests']['sum']).to eq(30)
        expect(values[1]['requests']['sum']).to eq(40)
        expect(values[2]['requests']['sum']).to eq(30)
        expect(values[3]['requests']['sum']).to eq(40)

        expect(values[0]['requests']).to include('items')
        expect(values[0]['metrics']).not_to have_key('sum')

        expect(series.series[:at]).to eq(original_series[:at])
      end

      it 'handles different path targets independently' do
        series.transpond.sum(values: 'metrics.scores', response: 'metrics.sum')

        values = series.series[:values]
        expect(values[0]['metrics']['sum']).to eq(20)
        expect(values[1]['metrics']['sum']).to eq(20)
        expect(values[2]['metrics']['sum']).to eq(20)
        expect(values[3]['metrics']['sum']).to eq(30)

        expect(values[0]['metrics']).to include('scores')
        expect(values[0]['requests']).not_to have_key('sum')
      end
    end

    context 'with custom key name' do
      it 'uses custom key for the calculated sum' do
        series.transpond.sum(values: 'requests.items', response: 'requests.total')

        expect(series.series[:values].first['requests']['total']).to eq(30)
        expect(series.series[:values].first['requests']).not_to have_key('sum')
      end

      it 'uses custom values field name' do
        custom_series_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'metrics' => { 'numbers' => [5, 10, 15, 20] } }]
        }
        custom_series = Trifle::Stats::Series.new(custom_series_data)

        custom_series.transpond.sum(values: 'metrics.numbers', response: 'metrics.sum')

        expect(custom_series.series[:values].first['metrics']['sum']).to eq(50)
      end
    end

    context 'with root path (potential bug scenario)' do
      let(:root_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'values' => [25, 15, 10], 'other' => 999 }]
        }
      end
      let(:root_series) { Trifle::Stats::Series.new(root_series_data) }

      it 'handles empty path correctly' do
        root_series.transpond.sum(values: 'values', response: 'sum')

        expect(root_series.series[:values].first['sum']).to eq(50)
        expect(root_series.series[:values].first.keys).to include('values', 'other', 'sum')
      end
    end

    context 'with nested paths' do
      let(:nested_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'stats' => { 
              'web' => { 'requests' => { 'items' => [100, 75, 25] } }
            }
          }]
        }
      end
      let(:nested_series) { Trifle::Stats::Series.new(nested_series_data) }

      it 'calculates sum for deeply nested paths' do
        nested_series.transpond.sum(values: 'stats.web.requests.items', response: 'stats.web.requests.sum')

        expected_value = nested_series.series[:values].first
        expect(expected_value.dig('stats', 'web', 'requests', 'sum')).to eq(200)
        expect(expected_value.dig('stats', 'web', 'requests', 'items')).to eq([100, 75, 25])
      end

      it 'handles nested values field path' do
        complex_nested_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'metrics' => { 
              'data' => { 'numbers' => [12, 8, 15, 5] }
            }
          }]
        }
        complex_series = Trifle::Stats::Series.new(complex_nested_data)

        complex_series.transpond.sum(
          values: 'metrics.data.numbers',
          response: 'metrics.sum'
        )

        expect(complex_series.series[:values].first.dig('metrics', 'sum')).to eq(40)
      end
    end

    context 'with missing data' do
      let(:incomplete_series_data) do
        {
          at: [
            Time.parse('2023-01-01 10:00:00'),
            Time.parse('2023-01-01 11:00:00'),
            Time.parse('2023-01-01 12:00:00')
          ],
          values: [
            { 'requests' => { 'items' => [10, 5, 15] } },
            { 'requests' => {} }, # Missing items
            { 'requests' => { 'items' => [] } }  # Empty items
          ]
        }
      end
      let(:incomplete_series) { Trifle::Stats::Series.new(incomplete_series_data) }

      it 'skips calculation when values array is missing' do
        incomplete_series.transpond.sum(values: 'requests.items', response: 'requests.sum')

        values = incomplete_series.series[:values]
        expect(values[0]['requests']['items'].map(&:to_i)).to eq([10, 5, 15])
        expect(values[0]['requests']['sum'].to_i).to eq(30)
        expect(values[1]).to eq({ 'requests' => {} })
        expect(values[2]['requests']['items']).to eq([])
        expect(values[2]['requests']['sum'].to_i).to eq(0) # Empty array gets sum of 0
      end

      it 'handles completely missing path gracefully' do
        incomplete_series.transpond.sum(values: 'nonexistent.items', response: 'nonexistent.sum')

        values = incomplete_series.series[:values]
        expect(values[0]['requests']['items'].map(&:to_i)).to eq([10, 5, 15])
        expect(values[1]).to eq({ 'requests' => {} })
        expect(values[2]['requests']['items']).to eq([])
      end
    end

    context 'with edge case values' do
      let(:edge_case_data) do
        {
          at: [
            Time.parse('2023-01-01 10:00:00'),
            Time.parse('2023-01-01 11:00:00'),
            Time.parse('2023-01-01 12:00:00'),
            Time.parse('2023-01-01 13:00:00')
          ],
          values: [
            { 'metrics' => { 'items' => [] } },                  # Empty array
            { 'metrics' => { 'items' => [0, 0, 0] } },          # All zeros
            { 'metrics' => { 'items' => [-5, 10, -3] } },       # Mixed positive/negative
            { 'metrics' => { 'items' => ['5', 10, '15'] } }     # Mixed string/numeric
          ]
        }
      end
      let(:edge_series) { Trifle::Stats::Series.new(edge_case_data) }

      it 'handles empty array correctly' do
        edge_series.transpond.sum(values: 'metrics.items', response: 'metrics.sum')
        expect(edge_series.series[:values][0]['metrics']['sum']).to eq(0)
      end

      it 'handles all zero values correctly' do
        edge_series.transpond.sum(values: 'metrics.items', response: 'metrics.sum')
        expect(edge_series.series[:values][1]['metrics']['sum']).to eq(0)
      end

      it 'handles negative values correctly' do
        edge_series.transpond.sum(values: 'metrics.items', response: 'metrics.sum')
        expect(edge_series.series[:values][2]['metrics']['sum']).to eq(2)
      end

      it 'handles mixed string/numeric values correctly' do
        edge_series.transpond.sum(values: 'metrics.items', response: 'metrics.sum')
        expect(edge_series.series[:values][3]['metrics']['sum'].to_f).to eq(30.0) # Only numeric values summed
      end
    end

    context 'with multiple transponder calls' do
      it 'can apply multiple sums to different paths' do
        series.transpond.sum(values: 'requests.items', response: 'requests.sum')
        series.transpond.sum(values: 'metrics.scores', response: 'metrics.total')

        first_value = series.series[:values].first
        expect(first_value['requests']).to include('sum' => 30)
        expect(first_value['metrics']).to include('total' => 20)
      end

      it 'preserves existing calculated values when adding new ones' do
        series.transpond.sum(values: 'requests.items', response: 'requests.sum')
        original_requests_sum = series.series[:values].first['requests']['sum']

        series.transpond.sum(values: 'metrics.scores', response: 'metrics.sum')

        expect(series.series[:values].first['requests']['sum']).to eq(original_requests_sum)
        expect(series.series[:values].first['metrics']).to include('sum')
      end
    end
  end

  describe 'integration with Series' do
    it 'is properly registered as sum transponder' do
      expect(series.transpond).to respond_to(:sum)
    end

    it 'modifies the series in place' do
      original_object_id = series.series[:values].object_id
      series.transpond.sum(values: 'requests.items', response: 'requests.sum')
      
      expect(series.series[:values]).not_to eq(original_object_id)
      expect(series.series[:values].first['requests']).to include('sum')
    end

    it 'returns the modified series for chaining' do
      result = series.transpond.sum(values: 'requests.items', response: 'requests.sum')
      expect(result).to eq(series.series)
    end

    it 'can be combined with other series operations' do
      series.transpond.sum(values: 'requests.items', response: 'requests.sum')
      totals = series.aggregate.sum(path: 'requests.sum')
      
      expect(totals).to eq([140]) # 30 + 40 + 30 + 40
    end
  end
end