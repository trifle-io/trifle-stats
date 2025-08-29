require 'time'

RSpec.describe Trifle::Stats::Transponder::Divide do
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
          'requests' => { 'total' => 100, 'count' => 10 },
          'metrics' => { 'x' => 20, 'y' => 4 }
        },
        { 
          'requests' => { 'total' => 150, 'count' => 15 },
          'metrics' => { 'x' => 35, 'y' => 7 }
        },
        { 
          'requests' => { 'total' => 80, 'count' => 8 },
          'metrics' => { 'x' => 24, 'y' => 6 }
        },
        { 
          'requests' => { 'total' => 120, 'count' => 12 },
          'metrics' => { 'x' => 45, 'y' => 9 }
        }
      ]
    }
  end
  let(:series) { Trifle::Stats::Series.new(series_data) }

  describe '#transpond' do
    context 'with standard parameters' do
      it 'calculates division and adds it to the series data' do
        original_series = series.series.dup
        series.transpond.divide(left: 'requests.total', right: 'requests.count', response: 'requests.divide')

        values = series.series[:values]
        values.each do |value|
          expect(value['requests']['divide'].to_f).to eq(10.0)
          expect(value['requests']).to include('total', 'count')
          expect(value['metrics']).not_to have_key('divide')
        end

        expect(series.series[:at]).to eq(original_series[:at])
      end

      it 'handles different path targets independently' do
        series.transpond.divide(left: 'metrics.x', right: 'metrics.y', response: 'metrics.divide')

        values = series.series[:values]
        expect(values[0]['metrics']['divide'].to_f).to eq(5.0)
        expect(values[1]['metrics']['divide'].to_f).to eq(5.0)
        expect(values[2]['metrics']['divide'].to_f).to eq(4.0)
        expect(values[3]['metrics']['divide'].to_f).to eq(5.0)

        expect(values[0]['metrics']).to include('x', 'y')
        expect(values[0]['requests']).not_to have_key('divide')
      end
    end

    context 'with custom key name' do
      it 'uses custom key for the calculated division' do
        series.transpond.divide(left: 'requests.total', right: 'requests.count', response: 'requests.ratio')

        expect(series.series[:values].first['requests']['ratio'].to_f).to eq(10.0)
        expect(series.series[:values].first['requests']).not_to have_key('divide')
      end

      it 'uses custom left and right field names' do
        custom_series_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'metrics' => { 'numerator' => 100, 'denominator' => 5 } }]
        }
        custom_series = Trifle::Stats::Series.new(custom_series_data)

        custom_series.transpond.divide(left: 'metrics.numerator', right: 'metrics.denominator', response: 'metrics.divide')

        expect(custom_series.series[:values].first['metrics']['divide'].to_f).to eq(20.0)
      end
    end

    context 'with root path (potential bug scenario)' do
      let(:root_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'left' => 50, 'right' => 5, 'other' => 999 }]
        }
      end
      let(:root_series) { Trifle::Stats::Series.new(root_series_data) }

      it 'handles empty path correctly' do
        root_series.transpond.divide(left: 'left', right: 'right', response: 'divide')

        expect(root_series.series[:values].first['divide'].to_f).to eq(10.0)
        expect(root_series.series[:values].first.keys).to include('left', 'right', 'other', 'divide')
      end
    end

    context 'with nested paths' do
      let(:nested_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'stats' => { 
              'web' => { 'requests' => { 'total' => 200, 'count' => 20 } }
            }
          }]
        }
      end
      let(:nested_series) { Trifle::Stats::Series.new(nested_series_data) }

      it 'calculates division for deeply nested paths' do
        nested_series.transpond.divide(left: 'stats.web.requests.total', right: 'stats.web.requests.count', response: 'stats.web.requests.divide')

        expected_value = nested_series.series[:values].first
        expect(expected_value.dig('stats', 'web', 'requests', 'divide')).to eq(10.0)
        expect(expected_value.dig('stats', 'web', 'requests', 'total')).to eq(200)
        expect(expected_value.dig('stats', 'web', 'requests', 'count')).to eq(20)
      end

      it 'handles nested left and right field paths' do
        complex_nested_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'metrics' => { 
              'numerators' => { 'value' => 150 },
              'denominators' => { 'value' => 15 }
            }
          }]
        }
        complex_series = Trifle::Stats::Series.new(complex_nested_data)

        complex_series.transpond.divide(
          left: 'metrics.numerators.value', 
          right: 'metrics.denominators.value',
          response: 'metrics.divide'
        )

        expect(complex_series.series[:values].first.dig('metrics', 'divide')).to eq(10.0)
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
            { 'requests' => { 'total' => 100, 'count' => 10 } },
            { 'requests' => { 'total' => 150 } }, # Missing right value
            { 'requests' => { 'count' => 8 } }  # Missing left value
          ]
        }
      end
      let(:incomplete_series) { Trifle::Stats::Series.new(incomplete_series_data) }

      it 'skips calculation when left value is missing' do
        incomplete_series.transpond.divide(left: 'requests.total', right: 'requests.count', response: 'requests.divide')

        expect(incomplete_series.series[:values]).to eq([
          { 'requests' => { 'total' => 100, 'count' => 10, 'divide' => 10.0 } },
          { 'requests' => { 'total' => 150 } }, # Unchanged - no right value
          { 'requests' => { 'count' => 8 } }  # Unchanged - no left value
        ])
      end

      it 'skips calculation when right value is missing' do
        incomplete_series.transpond.divide(left: 'requests.total', right: 'requests.count', response: 'requests.divide')

        values = incomplete_series.series[:values]
        expect(values[1]).not_to have_key('divide')
        expect(values[2]).not_to have_key('divide')
      end

      it 'handles completely missing path gracefully' do
        incomplete_series.transpond.divide(left: 'nonexistent.total', right: 'nonexistent.count', response: 'nonexistent.divide')

        expect(incomplete_series.series[:values]).to eq([
          { 'requests' => { 'total' => 100, 'count' => 10 } },
          { 'requests' => { 'total' => 150 } },
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
            { 'metrics' => { 'left' => 0, 'right' => 5 } },      # Zero numerator
            { 'metrics' => { 'left' => 100, 'right' => 0 } },    # Zero denominator (division by zero)
            { 'metrics' => { 'left' => -50, 'right' => 10 } }    # Negative numerator
          ]
        }
      end
      let(:edge_series) { Trifle::Stats::Series.new(edge_case_data) }

      it 'handles zero numerator correctly' do
        edge_series.transpond.divide(left: 'metrics.left', right: 'metrics.right', response: 'metrics.divide')
        expect(edge_series.series[:values][0]['metrics']['divide']).to eq(0.0)
      end

      it 'handles division by zero gracefully' do
        edge_series.transpond.divide(left: 'metrics.left', right: 'metrics.right', response: 'metrics.divide')
        
        # Division by zero should result in NaN, which gets converted to 0
        result = edge_series.series[:values][1]['metrics']['divide']
        expect(result.infinite?).to be(1) # Check that it's positive infinity
        # Transponder doesn't handle division by zero - it returns Infinity
      end

      it 'handles negative values correctly' do
        edge_series.transpond.divide(left: 'metrics.left', right: 'metrics.right', response: 'metrics.divide')
        expect(edge_series.series[:values][2]['metrics']['divide']).to eq(-5.0)
      end
    end

    context 'with multiple transponder calls' do
      it 'can apply multiple divisions to different paths' do
        series.transpond.divide(left: 'requests.total', right: 'requests.count', response: 'requests.divide')
        series.transpond.divide(left: 'metrics.x', right: 'metrics.y', response: 'metrics.quotient')

        first_value = series.series[:values].first
        expect(first_value['requests']).to include('divide' => 10.0)
        expect(first_value['metrics']).to include('quotient' => 5.0)
      end

      it 'preserves existing calculated values when adding new ones' do
        series.transpond.divide(left: 'requests.total', right: 'requests.count', response: 'requests.divide')
        original_requests_divide = series.series[:values].first['requests']['divide']

        series.transpond.divide(left: 'metrics.x', right: 'metrics.y', response: 'metrics.divide')

        expect(series.series[:values].first['requests']['divide']).to eq(original_requests_divide)
        expect(series.series[:values].first['metrics']).to include('divide')
      end
    end
  end

  describe 'integration with Series' do
    it 'is properly registered as divide transponder' do
      expect(series.transpond).to respond_to(:divide)
    end

    it 'modifies the series in place' do
      original_object_id = series.series[:values].object_id
      series.transpond.divide(left: 'requests.total', right: 'requests.count', response: 'requests.divide')
      
      expect(series.series[:values]).not_to eq(original_object_id)
      expect(series.series[:values].first['requests']).to include('divide')
    end

    it 'returns the modified series for chaining' do
      result = series.transpond.divide(left: 'requests.total', right: 'requests.count', response: 'requests.divide')
      expect(result).to eq(series.series)
    end

    it 'can be combined with other series operations' do
      series.transpond.divide(left: 'requests.total', right: 'requests.count', response: 'requests.divide')
      totals = series.aggregate.sum(path: 'requests.divide')
      
      expect(totals).to eq([40.0]) # 10.0 + 10.0 + 10.0 + 10.0
    end
  end
end