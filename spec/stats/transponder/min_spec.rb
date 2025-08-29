require 'time'

RSpec.describe Trifle::Stats::Transponder::Min do
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
          'requests' => { 'items' => [10, 5, 15, 3, 8] },
          'metrics' => { 'scores' => [8, 2, 7, 3, 12] }
        },
        { 
          'requests' => { 'items' => [20, 8, 12, 18] },
          'metrics' => { 'scores' => [9, 4, 6, 1] }
        },
        { 
          'requests' => { 'items' => [5, 15, 10, 25] },
          'metrics' => { 'scores' => [7, 3, 8, 2, 11] }
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
      it 'calculates minimum of array values and adds it to the series data' do
        original_series = series.series.dup
        series.transpond.min(values: 'requests.items', response: 'requests.min')

        values = series.series[:values]
        expect(values[0]['requests']['min']).to eq(3)
        expect(values[1]['requests']['min']).to eq(8)
        expect(values[2]['requests']['min']).to eq(5)
        expect(values[3]['requests']['min']).to eq(5)

        expect(values[0]['requests']).to include('items')
        expect(values[0]['metrics']).not_to have_key('min')

        expect(series.series[:at]).to eq(original_series[:at])
      end

      it 'handles different path targets independently' do
        series.transpond.min(values: 'metrics.scores', response: 'metrics.min')

        values = series.series[:values]
        expect(values[0]['metrics']['min']).to eq(2)
        expect(values[1]['metrics']['min']).to eq(1)
        expect(values[2]['metrics']['min']).to eq(2)
        expect(values[3]['metrics']['min']).to eq(5)

        expect(values[0]['metrics']).to include('scores')
        expect(values[0]['requests']).not_to have_key('min')
      end
    end

    context 'with custom key name' do
      it 'uses custom key for the calculated minimum' do
        series.transpond.min(values: 'requests.items', response: 'requests.minimum')

        expect(series.series[:values].first['requests']['minimum']).to eq(3)
        expect(series.series[:values].first['requests']).not_to have_key('min')
      end

      it 'uses custom values field name' do
        custom_series_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'metrics' => { 'numbers' => [15, 3, 9, 22, 7] } }]
        }
        custom_series = Trifle::Stats::Series.new(custom_series_data)

        custom_series.transpond.min(values: 'metrics.numbers', response: 'metrics.min')

        expect(custom_series.series[:values].first['metrics']['min']).to eq(3)
      end
    end

    context 'with root path (potential bug scenario)' do
      let(:root_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'values' => [25, 15, 5, 30], 'other' => 999 }]
        }
      end
      let(:root_series) { Trifle::Stats::Series.new(root_series_data) }

      it 'handles empty path correctly' do
        root_series.transpond.min(values: 'values', response: 'min')

        expect(root_series.series[:values].first['min']).to eq(5)
        expect(root_series.series[:values].first.keys).to include('values', 'other', 'min')
      end
    end

    context 'with nested paths' do
      let(:nested_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'stats' => { 
              'web' => { 'requests' => { 'items' => [100, 25, 75, 50] } }
            }
          }]
        }
      end
      let(:nested_series) { Trifle::Stats::Series.new(nested_series_data) }

      it 'calculates minimum for deeply nested paths' do
        nested_series.transpond.min(values: 'stats.web.requests.items', response: 'stats.web.requests.min')

        expected_value = nested_series.series[:values].first
        expect(expected_value.dig('stats', 'web', 'requests', 'min')).to eq(25)
        expect(expected_value.dig('stats', 'web', 'requests', 'items')).to eq([100, 25, 75, 50])
      end

      it 'handles nested values field path' do
        complex_nested_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'metrics' => { 
              'data' => { 'numbers' => [12, 8, 15, 5, 20] }
            }
          }]
        }
        complex_series = Trifle::Stats::Series.new(complex_nested_data)

        complex_series.transpond.min(
          values: 'metrics.data.numbers',
          response: 'metrics.min'
        )

        expect(complex_series.series[:values].first.dig('metrics', 'min')).to eq(5)
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
        incomplete_series.transpond.min(values: 'requests.items', response: 'requests.min')

        expect(incomplete_series.series[:values]).to eq([
          { 'requests' => { 'items' => [10, 5, 15], 'min' => 5 } },
          { 'requests' => {} }, # Unchanged - no items
          { 'requests' => { 'items' => [] } }  # Unchanged - empty items
        ])
      end

      it 'handles completely missing path gracefully' do
        incomplete_series.transpond.min(values: 'nonexistent.items', response: 'nonexistent.min')

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
            { 'metrics' => { 'items' => [] } },                    # Empty array
            { 'metrics' => { 'items' => [0, -5, 10] } },          # Contains zero and negative
            { 'metrics' => { 'items' => [-15, -3, -8] } },        # All negative
            { 'metrics' => { 'items' => ['5', 10, '15', 20] } }   # Mixed string/numeric
          ]
        }
      end
      let(:edge_series) { Trifle::Stats::Series.new(edge_case_data) }

      it 'skips calculation for empty array' do
        edge_series.transpond.min(values: 'metrics.items', response: 'metrics.min')
        
        values = edge_series.series[:values]
        expect(values[0]['metrics']).not_to have_key('min')
      end

      it 'handles zero and negative values correctly' do
        edge_series.transpond.min(values: 'metrics.items', response: 'metrics.min')
        expect(edge_series.series[:values][1]['metrics']['min']).to eq(-5)
      end

      it 'handles all negative values correctly' do
        edge_series.transpond.min(values: 'metrics.items', response: 'metrics.min')
        expect(edge_series.series[:values][2]['metrics']['min']).to eq(-15)
      end

      it 'handles mixed string/numeric values correctly' do
        edge_series.transpond.min(values: 'metrics.items', response: 'metrics.min')
        expect(edge_series.series[:values][3]['metrics']['min'].to_f).to eq(5.0) # Only numeric values: min of ['5', 10, '15', 20] -> min of [5, 10, 15, 20] = 5
      end
    end

    context 'with multiple transponder calls' do
      it 'can apply multiple mins to different paths' do
        series.transpond.min(values: 'requests.items', response: 'requests.min')
        series.transpond.min(values: 'metrics.scores', response: 'metrics.minimum')

        first_value = series.series[:values].first
        expect(first_value['requests']).to include('min' => 3)
        expect(first_value['metrics']).to include('minimum' => 2)
      end

      it 'preserves existing calculated values when adding new ones' do
        series.transpond.min(values: 'requests.items', response: 'requests.min')
        original_requests_min = series.series[:values].first['requests']['min']

        series.transpond.min(values: 'metrics.scores', response: 'metrics.min')

        expect(series.series[:values].first['requests']['min']).to eq(original_requests_min)
        expect(series.series[:values].first['metrics']).to include('min')
      end
    end
  end

  describe 'integration with Series' do
    it 'is properly registered as min transponder' do
      expect(series.transpond).to respond_to(:min)
    end

    it 'modifies the series in place' do
      original_object_id = series.series[:values].object_id
      series.transpond.min(values: 'requests.items', response: 'requests.min')
      
      expect(series.series[:values]).not_to eq(original_object_id)
      expect(series.series[:values].first['requests']).to include('min')
    end

    it 'returns the modified series for chaining' do
      result = series.transpond.min(values: 'requests.items', response: 'requests.min')
      expect(result).to eq(series.series)
    end

    it 'can be combined with other series operations' do
      series.transpond.min(values: 'requests.items', response: 'requests.min')
      totals = series.aggregate.sum(path: 'requests.min')
      
      expect(totals).to eq([21]) # 3 + 8 + 5 + 5
    end
  end
end