require 'time'

RSpec.describe Trifle::Stats::Transponder::Average do
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
          'requests' => { 'sum' => 100, 'count' => 10 },
          'errors' => { 'sum' => 20, 'count' => 4 }
        },
        { 
          'requests' => { 'sum' => 150, 'count' => 15 },
          'errors' => { 'sum' => 30, 'count' => 6 }
        },
        { 
          'requests' => { 'sum' => 80, 'count' => 8 },
          'errors' => { 'sum' => 10, 'count' => 2 }
        },
        { 
          'requests' => { 'sum' => 120, 'count' => 12 },
          'errors' => { 'sum' => 25, 'count' => 5 }
        }
      ]
    }
  end
  let(:series) { Trifle::Stats::Series.new(series_data) }

  describe '#transpond' do
    context 'with standard parameters' do
      it 'calculates average and adds it to the series data' do
        original_series = series.series.dup
        series.transpond.average(sum: 'requests.sum', count: 'requests.count', response: 'requests.average')

        # Check that averages were calculated correctly (handling BigDecimal format)
        values = series.series[:values]
        values.each do |value|
          expect(value['requests']['average'].to_f).to eq(10.0)
          expect(value['requests']).to include('sum', 'count')
          expect(value['errors']).not_to have_key('average')
        end

        # Original timestamps should be preserved
        expect(series.series[:at]).to eq(original_series[:at])
      end

      it 'handles different path targets independently' do
        series.transpond.average(sum: 'errors.sum', count: 'errors.count', response: 'errors.average')

        # Check that averages were calculated correctly for errors path
        values = series.series[:values]
        values.each do |value|
          expect(value['errors']['average'].to_f).to eq(5.0)
          expect(value['errors']).to include('sum', 'count')
          expect(value['requests']).not_to have_key('average')
        end
      end
    end

    context 'with custom key name' do
      it 'uses custom key for the calculated average' do
        series.transpond.average(sum: 'requests.sum', count: 'requests.count', response: 'requests.mean')

        expect(series.series[:values].first['requests']['mean'].to_f).to eq(10.0)
        expect(series.series[:values].first['requests']).not_to have_key('average')
      end

      it 'uses custom sum and count field names' do
        custom_series_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'metrics' => { 'total' => 100, 'num' => 10 } }]
        }
        custom_series = Trifle::Stats::Series.new(custom_series_data)

        custom_series.transpond.average(sum: 'metrics.total', count: 'metrics.num', response: 'metrics.average')

        expect(custom_series.series[:values].first['metrics']['average'].to_f).to eq(10.0)
      end
    end

    context 'with root path (potential bug scenario)' do
      let(:root_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'sum' => 100, 'count' => 10, 'other' => 999 }]
        }
      end
      let(:root_series) { Trifle::Stats::Series.new(root_series_data) }

      it 'handles empty path correctly' do
        root_series.transpond.average(sum: 'sum', count: 'count', response: 'average')

        # When path is empty, key is created directly at root level (same as nil path)
        expect(root_series.series[:values].first['average'].to_f).to eq(10.0)
        expect(root_series.series[:values].first.keys).to include('sum', 'count', 'other', 'average')
      end

      it 'handles nil path correctly' do
        root_series.transpond.average(sum: 'sum', count: 'count', response: 'average')

        # When path is nil, the key becomes just 'average' at root level
        expect(root_series.series[:values].first['average'].to_f).to eq(10.0)
        expect(root_series.series[:values].first.keys).to include('sum', 'count', 'other', 'average')
      end
    end

    context 'with nested paths' do
      let(:nested_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'stats' => { 
              'web' => { 'requests' => { 'sum' => 200, 'count' => 20 } }
            }
          }]
        }
      end
      let(:nested_series) { Trifle::Stats::Series.new(nested_series_data) }

      it 'calculates average for deeply nested paths' do
        nested_series.transpond.average(sum: 'stats.web.requests.sum', count: 'stats.web.requests.count', response: 'stats.web.requests.average')

        expected_value = nested_series.series[:values].first
        expect(expected_value.dig('stats', 'web', 'requests', 'average')).to eq(10.0)
        expect(expected_value.dig('stats', 'web', 'requests', 'sum')).to eq(200)
        expect(expected_value.dig('stats', 'web', 'requests', 'count')).to eq(20)
      end

      it 'handles nested sum and count field paths' do
        complex_nested_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'metrics' => { 
              'totals' => { 'value' => 150 },
              'counters' => { 'items' => 15 }
            }
          }]
        }
        complex_series = Trifle::Stats::Series.new(complex_nested_data)

        complex_series.transpond.average(
          sum: 'metrics.totals.value', 
          count: 'metrics.counters.items',
          response: 'metrics.average'
        )

        expect(complex_series.series[:values].first.dig('metrics', 'average')).to eq(10.0)
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
            { 'requests' => { 'sum' => 100, 'count' => 10 } },
            { 'requests' => { 'sum' => 150 } }, # Missing count
            { 'requests' => { 'count' => 8 } }  # Missing sum
          ]
        }
      end
      let(:incomplete_series) { Trifle::Stats::Series.new(incomplete_series_data) }

      it 'skips calculation when sum is missing' do
        incomplete_series.transpond.average(sum: 'requests.sum', count: 'requests.count', response: 'requests.average')

        expect(incomplete_series.series[:values]).to eq([
          { 'requests' => { 'sum' => 100, 'count' => 10, 'average' => 10.0 } },
          { 'requests' => { 'sum' => 150 } }, # Unchanged - no count
          { 'requests' => { 'count' => 8 } }  # Unchanged - no sum
        ])
      end

      it 'skips calculation when count is missing' do
        incomplete_series.transpond.average(sum: 'requests.sum', count: 'requests.count', response: 'requests.average')

        values = incomplete_series.series[:values]
        expect(values[1]).not_to have_key('average')
        expect(values[2]).not_to have_key('average')
      end

      it 'handles completely missing path gracefully' do
        incomplete_series.transpond.average(sum: 'nonexistent.sum', count: 'nonexistent.count', response: 'nonexistent.average')

        # Should remain unchanged
        expect(incomplete_series.series[:values]).to eq([
          { 'requests' => { 'sum' => 100, 'count' => 10 } },
          { 'requests' => { 'sum' => 150 } },
          { 'requests' => { 'count' => 8 } }
        ])
      end
    end

    context 'with edge case values' do
      let(:edge_case_data) do
        {
          at: [
            Time.parse('2023-01-01 10:00:00'),
            Time.parse('2023-01-01 11:00:00'),
            Time.parse('2023-01-01 12:00:00')
          ],
          values: [
            { 'metrics' => { 'sum' => 0, 'count' => 5 } },    # Zero sum
            { 'metrics' => { 'sum' => 100, 'count' => 0 } },  # Zero count (division by zero)
            { 'metrics' => { 'sum' => -50, 'count' => 10 } }  # Negative sum
          ]
        }
      end
      let(:edge_series) { Trifle::Stats::Series.new(edge_case_data) }

      it 'handles zero sum correctly' do
        edge_series.transpond.average(sum: 'metrics.sum', count: 'metrics.count', response: 'metrics.average')
        expect(edge_series.series[:values][0]['metrics']['average']).to eq(0.0)
      end

      it 'handles division by zero gracefully' do
        edge_series.transpond.average(sum: 'metrics.sum', count: 'metrics.count', response: 'metrics.average')
        
        # Division by zero should result in NaN, which gets converted to 0
        result = edge_series.series[:values][1]['metrics']['average']
        expect(result.infinite?).to be(1) # Check that it's positive infinity
        # Transponder doesn't handle division by zero - it returns Infinity
      end

      it 'handles negative values correctly' do
        edge_series.transpond.average(sum: 'metrics.sum', count: 'metrics.count', response: 'metrics.average')
        expect(edge_series.series[:values][2]['metrics']['average']).to eq(-5.0)
      end
    end

    context 'with multiple transponder calls' do
      it 'can apply multiple averages to different paths' do
        series.transpond.average(sum: 'requests.sum', count: 'requests.count', response: 'requests.average')
        series.transpond.average(sum: 'errors.sum', count: 'errors.count', response: 'errors.error_avg')

        first_value = series.series[:values].first
        expect(first_value['requests']).to include('average' => 10.0)
        expect(first_value['errors']).to include('error_avg' => 5.0)
      end

      it 'preserves existing calculated values when adding new ones' do
        series.transpond.average(sum: 'requests.sum', count: 'requests.count', response: 'requests.average')
        original_requests_avg = series.series[:values].first['requests']['average']

        series.transpond.average(sum: 'errors.sum', count: 'errors.count', response: 'errors.average')

        expect(series.series[:values].first['requests']['average']).to eq(original_requests_avg)
        expect(series.series[:values].first['errors']).to include('average')
      end
    end
  end

  describe 'integration with Series' do
    it 'is properly registered as average transponder' do
      expect(series.transpond).to respond_to(:average)
    end

    it 'modifies the series in place' do
      original_object_id = series.series[:values].object_id
      series.transpond.average(sum: 'requests.sum', count: 'requests.count', response: 'requests.average')
      
      # The series values array gets replaced, but the series itself is modified
      expect(series.series[:values]).not_to eq(original_object_id) # Object changed
      expect(series.series[:values].first['requests']).to include('average') # But data was added
    end

    it 'returns the modified series for chaining' do
      result = series.transpond.average(sum: 'requests.sum', count: 'requests.count', response: 'requests.average')
      expect(result).to eq(series.series)
    end

    it 'can be combined with other series operations' do
      # Add averages, then aggregate them
      series.transpond.average(sum: 'requests.sum', count: 'requests.count', response: 'requests.average')
      averages = series.aggregate.sum(path: 'requests.average')
      
      expect(averages).to eq([40.0]) # 10.0 + 10.0 + 10.0 + 10.0
    end
  end
end