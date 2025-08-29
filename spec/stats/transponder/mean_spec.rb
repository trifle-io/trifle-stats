require 'time'

RSpec.describe Trifle::Stats::Transponder::Mean do
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
      it 'calculates mean of array values and adds it to the series data' do
        original_series = series.series.dup
        series.transpond.mean(values: 'requests.items', response: 'requests.mean')

        values = series.series[:values]
        expect(values[0]['requests']['mean']).to eq(10.0)
        expect(values[1]['requests']['mean']).to be_within(0.01).of(13.33)
        expect(values[2]['requests']['mean']).to eq(10.0)
        expect(values[3]['requests']['mean']).to be_within(0.01).of(13.33)

        expect(values[0]['requests']).to include('items')
        expect(values[0]['metrics']).not_to have_key('mean')

        expect(series.series[:at]).to eq(original_series[:at])
      end

      it 'handles different path targets independently' do
        series.transpond.mean(values: 'metrics.scores', response: 'metrics.mean')

        values = series.series[:values]
        expect(values[0]['metrics']['mean']).to eq(5.0)
        expect(values[1]['metrics']['mean']).to eq(5.0)
        expect(values[2]['metrics']['mean']).to eq(5.0)
        expect(values[3]['metrics']['mean']).to eq(7.5)

        expect(values[0]['metrics']).to include('scores')
        expect(values[0]['requests']).not_to have_key('mean')
      end
    end

    context 'with custom key name' do
      it 'uses custom key for the calculated mean' do
        series.transpond.mean(values: 'requests.items', response: 'requests.average')

        expect(series.series[:values].first['requests']['average']).to eq(10.0)
        expect(series.series[:values].first['requests']).not_to have_key('mean')
      end

      it 'uses custom values field name' do
        custom_series_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'metrics' => { 'numbers' => [10, 20, 30, 40] } }]
        }
        custom_series = Trifle::Stats::Series.new(custom_series_data)

        custom_series.transpond.mean(values: 'metrics.numbers', response: 'metrics.mean')

        expect(custom_series.series[:values].first['metrics']['mean']).to eq(25.0)
      end
    end

    context 'with root path (potential bug scenario)' do
      let(:root_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'values' => [10, 20, 30, 40], 'other' => 999 }]
        }
      end
      let(:root_series) { Trifle::Stats::Series.new(root_series_data) }

      it 'handles empty path correctly' do
        root_series.transpond.mean(values: 'values', response: 'mean')

        expect(root_series.series[:values].first['mean']).to eq(25.0)
        expect(root_series.series[:values].first.keys).to include('values', 'other', 'mean')
      end
    end

    context 'with nested paths' do
      let(:nested_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'stats' => { 
              'web' => { 'requests' => { 'items' => [100, 200, 300] } }
            }
          }]
        }
      end
      let(:nested_series) { Trifle::Stats::Series.new(nested_series_data) }

      it 'calculates mean for deeply nested paths' do
        nested_series.transpond.mean(values: 'stats.web.requests.items', response: 'stats.web.requests.mean')

        expected_value = nested_series.series[:values].first
        expect(expected_value.dig('stats', 'web', 'requests', 'mean')).to eq(200.0)
        expect(expected_value.dig('stats', 'web', 'requests', 'items')).to eq([100, 200, 300])
      end

      it 'handles nested values field path' do
        complex_nested_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'metrics' => { 
              'data' => { 'numbers' => [5, 10, 15, 20] }
            }
          }]
        }
        complex_series = Trifle::Stats::Series.new(complex_nested_data)

        complex_series.transpond.mean(
          values: 'metrics.data.numbers',
          response: 'metrics.mean'
        )

        expect(complex_series.series[:values].first.dig('metrics', 'mean')).to eq(12.5)
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
            { 'requests' => { 'items' => [10, 20, 30] } },
            { 'requests' => {} }, # Missing items
            { 'requests' => { 'items' => [] } }  # Empty items
          ]
        }
      end
      let(:incomplete_series) { Trifle::Stats::Series.new(incomplete_series_data) }

      it 'skips calculation when values array is missing' do
        incomplete_series.transpond.mean(values: 'requests.items', response: 'requests.mean')

        expect(incomplete_series.series[:values]).to eq([
          { 'requests' => { 'items' => [10, 20, 30], 'mean' => 20.0 } },
          { 'requests' => {} }, # Unchanged - no items
          { 'requests' => { 'items' => [] } }  # Unchanged - empty items
        ])
      end

      it 'handles completely missing path gracefully' do
        incomplete_series.transpond.mean(values: 'nonexistent.items', response: 'nonexistent.mean')

        values = incomplete_series.series[:values]
        expect(values[0]['requests']['items'].map(&:to_i)).to eq([10, 20, 30])
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
            { 'metrics' => { 'items' => [-15, -3, -6] } },        # All negative
            { 'metrics' => { 'items' => ['5', 10, '15', 20] } }   # Mixed string/numeric
          ]
        }
      end
      let(:edge_series) { Trifle::Stats::Series.new(edge_case_data) }

      it 'skips calculation for empty array' do
        edge_series.transpond.mean(values: 'metrics.items', response: 'metrics.mean')
        
        values = edge_series.series[:values]
        expect(values[0]['metrics']).not_to have_key('mean')
      end

      it 'handles zero and negative values correctly' do
        edge_series.transpond.mean(values: 'metrics.items', response: 'metrics.mean')
        expect(edge_series.series[:values][1]['metrics']['mean']).to be_within(0.01).of(1.67)
      end

      it 'handles all negative values correctly' do
        edge_series.transpond.mean(values: 'metrics.items', response: 'metrics.mean')
        expect(edge_series.series[:values][2]['metrics']['mean']).to eq(-8.0)
      end

      it 'handles mixed string/numeric values correctly' do
        edge_series.transpond.mean(values: 'metrics.items', response: 'metrics.mean')
        expect(edge_series.series[:values][3]['metrics']['mean'].to_f).to eq(12.5) # Only numeric values: (5 + 10 + 15 + 20) / 4 = 12.5
      end
    end

    context 'with multiple transponder calls' do
      it 'can apply multiple means to different paths' do
        series.transpond.mean(values: 'requests.items', response: 'requests.mean')
        series.transpond.mean(values: 'metrics.scores', response: 'metrics.average')

        first_value = series.series[:values].first
        expect(first_value['requests']).to include('mean' => 10.0)
        expect(first_value['metrics']).to include('average' => 5.0)
      end

      it 'preserves existing calculated values when adding new ones' do
        series.transpond.mean(values: 'requests.items', response: 'requests.mean')
        original_requests_mean = series.series[:values].first['requests']['mean']

        series.transpond.mean(values: 'metrics.scores', response: 'metrics.mean')

        expect(series.series[:values].first['requests']['mean']).to eq(original_requests_mean)
        expect(series.series[:values].first['metrics']).to include('mean')
      end
    end
  end

  describe 'integration with Series' do
    it 'is properly registered as mean transponder' do
      expect(series.transpond).to respond_to(:mean)
    end

    it 'modifies the series in place' do
      original_object_id = series.series[:values].object_id
      series.transpond.mean(values: 'requests.items', response: 'requests.mean')
      
      expect(series.series[:values]).not_to eq(original_object_id)
      expect(series.series[:values].first['requests']).to include('mean')
    end

    it 'returns the modified series for chaining' do
      result = series.transpond.mean(values: 'requests.items', response: 'requests.mean')
      expect(result).to eq(series.series)
    end

    it 'can be combined with other series operations' do
      series.transpond.mean(values: 'requests.items', response: 'requests.mean')
      totals = series.aggregate.sum(path: 'requests.mean')
      
      expect(totals[0]).to be_within(0.01).of(46.66) # 10.0 + 13.33 + 10.0 + 13.33
    end
  end
end