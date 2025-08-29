require 'time'

RSpec.describe Trifle::Stats::Transponder::Max do
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
      it 'calculates maximum of array values and adds it to the series data' do
        original_series = series.series.dup
        series.transpond.max(values: 'requests.items', response: 'requests.max')

        values = series.series[:values]
        expect(values[0]['requests']['max']).to eq(15)
        expect(values[1]['requests']['max']).to eq(20)
        expect(values[2]['requests']['max']).to eq(25)
        expect(values[3]['requests']['max']).to eq(25)

        expect(values[0]['requests']).to include('items')
        expect(values[0]['metrics']).not_to have_key('max')

        expect(series.series[:at]).to eq(original_series[:at])
      end

      it 'handles different path targets independently' do
        series.transpond.max(values: 'metrics.scores', response: 'metrics.max')

        values = series.series[:values]
        expect(values[0]['metrics']['max']).to eq(12)
        expect(values[1]['metrics']['max']).to eq(9)
        expect(values[2]['metrics']['max']).to eq(11)
        expect(values[3]['metrics']['max']).to eq(10)

        expect(values[0]['metrics']).to include('scores')
        expect(values[0]['requests']).not_to have_key('max')
      end
    end

    context 'with custom key name' do
      it 'uses custom key for the calculated maximum' do
        series.transpond.max(values: 'requests.items', response: 'requests.maximum')

        expect(series.series[:values].first['requests']['maximum']).to eq(15)
        expect(series.series[:values].first['requests']).not_to have_key('max')
      end

      it 'uses custom values field name' do
        custom_series_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'metrics' => { 'numbers' => [15, 3, 9, 22, 7] } }]
        }
        custom_series = Trifle::Stats::Series.new(custom_series_data)

        custom_series.transpond.max(values: 'metrics.numbers', response: 'metrics.max')

        expect(custom_series.series[:values].first['metrics']['max']).to eq(22)
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
        root_series.transpond.max(values: 'values', response: 'max')

        expect(root_series.series[:values].first['max']).to eq(30)
        expect(root_series.series[:values].first.keys).to include('values', 'other', 'max')
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

      it 'calculates maximum for deeply nested paths' do
        nested_series.transpond.max(values: 'stats.web.requests.items', response: 'stats.web.requests.max')

        expected_value = nested_series.series[:values].first
        expect(expected_value.dig('stats', 'web', 'requests', 'max')).to eq(100)
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

        complex_series.transpond.max(
          values: 'metrics.data.numbers',
          response: 'metrics.max'
        )

        expect(complex_series.series[:values].first.dig('metrics', 'max')).to eq(20)
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
        incomplete_series.transpond.max(values: 'requests.items', response: 'requests.max')

        expect(incomplete_series.series[:values]).to eq([
          { 'requests' => { 'items' => [10, 5, 15], 'max' => 15 } },
          { 'requests' => {} }, # Unchanged - no items
          { 'requests' => { 'items' => [] } }  # Unchanged - empty items
        ])
      end

      it 'handles completely missing path gracefully' do
        incomplete_series.transpond.max(values: 'nonexistent.items', response: 'nonexistent.max')

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
        edge_series.transpond.max(values: 'metrics.items', response: 'metrics.max')
        
        values = edge_series.series[:values]
        expect(values[0]['metrics']).not_to have_key('max')
      end

      it 'handles zero and negative values correctly' do
        edge_series.transpond.max(values: 'metrics.items', response: 'metrics.max')
        expect(edge_series.series[:values][1]['metrics']['max']).to eq(10)
      end

      it 'handles all negative values correctly' do
        edge_series.transpond.max(values: 'metrics.items', response: 'metrics.max')
        expect(edge_series.series[:values][2]['metrics']['max']).to eq(-3)
      end

      it 'handles mixed string/numeric values correctly' do
        edge_series.transpond.max(values: 'metrics.items', response: 'metrics.max')
        expect(edge_series.series[:values][3]['metrics']['max']).to eq(20) # Only numeric values considered
      end
    end

    context 'with multiple transponder calls' do
      it 'can apply multiple maxs to different paths' do
        series.transpond.max(values: 'requests.items', response: 'requests.max')
        series.transpond.max(values: 'metrics.scores', response: 'metrics.maximum')

        first_value = series.series[:values].first
        expect(first_value['requests']).to include('max' => 15)
        expect(first_value['metrics']).to include('maximum' => 12)
      end

      it 'preserves existing calculated values when adding new ones' do
        series.transpond.max(values: 'requests.items', response: 'requests.max')
        original_requests_max = series.series[:values].first['requests']['max']

        series.transpond.max(values: 'metrics.scores', response: 'metrics.max')

        expect(series.series[:values].first['requests']['max']).to eq(original_requests_max)
        expect(series.series[:values].first['metrics']).to include('max')
      end
    end
  end

  describe 'integration with Series' do
    it 'is properly registered as max transponder' do
      expect(series.transpond).to respond_to(:max)
    end

    it 'modifies the series in place' do
      original_object_id = series.series[:values].object_id
      series.transpond.max(values: 'requests.items', response: 'requests.max')
      
      expect(series.series[:values]).not_to eq(original_object_id)
      expect(series.series[:values].first['requests']).to include('max')
    end

    it 'returns the modified series for chaining' do
      result = series.transpond.max(values: 'requests.items', response: 'requests.max')
      expect(result).to eq(series.series)
    end

    it 'can be combined with other series operations' do
      series.transpond.max(values: 'requests.items', response: 'requests.max')
      totals = series.aggregate.sum(path: 'requests.max')
      
      expect(totals).to eq([85]) # 15 + 20 + 25 + 25
    end
  end
end