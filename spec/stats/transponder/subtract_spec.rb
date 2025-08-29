require 'time'

RSpec.describe Trifle::Stats::Transponder::Subtract do
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
          'requests' => { 'value_a' => 20, 'value_b' => 5 },
          'metrics' => { 'x' => 10, 'y' => 3 }
        },
        { 
          'requests' => { 'value_a' => 25, 'value_b' => 8 },
          'metrics' => { 'x' => 15, 'y' => 6 }
        },
        { 
          'requests' => { 'value_a' => 18, 'value_b' => 3 },
          'metrics' => { 'x' => 12, 'y' => 4 }
        },
        { 
          'requests' => { 'value_a' => 30, 'value_b' => 10 },
          'metrics' => { 'x' => 20, 'y' => 5 }
        }
      ]
    }
  end
  let(:series) { Trifle::Stats::Series.new(series_data) }

  describe '#transpond' do
    context 'with standard parameters' do
      it 'calculates subtraction and adds it to the series data' do
        original_series = series.series.dup
        series.transpond.subtract(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.subtract')

        values = series.series[:values]
        expect(values[0]['requests']['subtract']).to eq(15)
        expect(values[1]['requests']['subtract']).to eq(17)
        expect(values[2]['requests']['subtract']).to eq(15)
        expect(values[3]['requests']['subtract']).to eq(20)

        expect(values[0]['requests']).to include('value_a', 'value_b')
        expect(values[0]['metrics']).not_to have_key('subtract')

        expect(series.series[:at]).to eq(original_series[:at])
      end

      it 'handles different path targets independently' do
        series.transpond.subtract(left: 'metrics.x', right: 'metrics.y', response: 'metrics.subtract')

        values = series.series[:values]
        expect(values[0]['metrics']['subtract']).to eq(7)
        expect(values[1]['metrics']['subtract']).to eq(9)
        expect(values[2]['metrics']['subtract']).to eq(8)
        expect(values[3]['metrics']['subtract']).to eq(15)

        expect(values[0]['metrics']).to include('x', 'y')
        expect(values[0]['requests']).not_to have_key('subtract')
      end
    end

    context 'with custom key name' do
      it 'uses custom key for the calculated subtraction' do
        series.transpond.subtract(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.difference')

        expect(series.series[:values].first['requests']['difference']).to eq(15)
        expect(series.series[:values].first['requests']).not_to have_key('subtract')
      end

      it 'uses custom left and right field names' do
        custom_series_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'metrics' => { 'first' => 40, 'second' => 15 } }]
        }
        custom_series = Trifle::Stats::Series.new(custom_series_data)

        custom_series.transpond.subtract(left: 'metrics.first', right: 'metrics.second', response: 'metrics.subtract')

        expect(custom_series.series[:values].first['metrics']['subtract']).to eq(25)
      end
    end

    context 'with root path (potential bug scenario)' do
      let(:root_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'left' => 100, 'right' => 30, 'other' => 999 }]
        }
      end
      let(:root_series) { Trifle::Stats::Series.new(root_series_data) }

      it 'handles empty path correctly' do
        root_series.transpond.subtract(left: 'left', right: 'right', response: 'subtract')

        expect(root_series.series[:values].first['subtract']).to eq(70)
        expect(root_series.series[:values].first.keys).to include('left', 'right', 'other', 'subtract')
      end
    end

    context 'with nested paths' do
      let(:nested_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'stats' => { 
              'web' => { 'requests' => { 'value_a' => 200, 'value_b' => 50 } }
            }
          }]
        }
      end
      let(:nested_series) { Trifle::Stats::Series.new(nested_series_data) }

      it 'calculates subtraction for deeply nested paths' do
        nested_series.transpond.subtract(left: 'stats.web.requests.value_a', right: 'stats.web.requests.value_b', response: 'stats.web.requests.subtract')

        expected_value = nested_series.series[:values].first
        expect(expected_value.dig('stats', 'web', 'requests', 'subtract')).to eq(150)
        expect(expected_value.dig('stats', 'web', 'requests', 'value_a')).to eq(200)
        expect(expected_value.dig('stats', 'web', 'requests', 'value_b')).to eq(50)
      end

      it 'handles nested left and right field paths' do
        complex_nested_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'metrics' => { 
              'left_values' => { 'amount' => 80 },
              'right_values' => { 'amount' => 30 }
            }
          }]
        }
        complex_series = Trifle::Stats::Series.new(complex_nested_data)

        complex_series.transpond.subtract(
          left: 'metrics.left_values.amount', 
          right: 'metrics.right_values.amount',
          response: 'metrics.subtract'
        )

        expect(complex_series.series[:values].first.dig('metrics', 'subtract')).to eq(50)
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
            { 'requests' => { 'value_a' => 20, 'value_b' => 5 } },
            { 'requests' => { 'value_a' => 25 } }, # Missing right value
            { 'requests' => { 'value_b' => 8 } }  # Missing left value
          ]
        }
      end
      let(:incomplete_series) { Trifle::Stats::Series.new(incomplete_series_data) }

      it 'skips calculation when left value is missing' do
        incomplete_series.transpond.subtract(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.subtract')

        expect(incomplete_series.series[:values]).to eq([
          { 'requests' => { 'value_a' => 20, 'value_b' => 5, 'subtract' => 15 } },
          { 'requests' => { 'value_a' => 25 } }, # Unchanged - no right value
          { 'requests' => { 'value_b' => 8 } }  # Unchanged - no left value
        ])
      end

      it 'skips calculation when right value is missing' do
        incomplete_series.transpond.subtract(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.subtract')

        values = incomplete_series.series[:values]
        expect(values[1]).not_to have_key('subtract')
        expect(values[2]).not_to have_key('subtract')
      end

      it 'handles completely missing path gracefully' do
        incomplete_series.transpond.subtract(left: 'nonexistent.value_a', right: 'nonexistent.value_b', response: 'nonexistent.subtract')

        expect(incomplete_series.series[:values]).to eq([
          { 'requests' => { 'value_a' => 20, 'value_b' => 5 } },
          { 'requests' => { 'value_a' => 25 } },
          { 'requests' => { 'value_b' => 8 } }
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
            { 'metrics' => { 'left' => 10, 'right' => 5 } },     # Normal case
            { 'metrics' => { 'left' => 5, 'right' => 10 } },     # Negative result
            { 'metrics' => { 'left' => 15, 'right' => -5 } }     # Negative right
          ]
        }
      end
      let(:edge_series) { Trifle::Stats::Series.new(edge_case_data) }

      it 'handles normal subtraction correctly' do
        edge_series.transpond.subtract(left: 'metrics.left', right: 'metrics.right', response: 'metrics.subtract')
        expect(edge_series.series[:values][0]['metrics']['subtract']).to eq(5)
      end

      it 'handles negative results correctly' do
        edge_series.transpond.subtract(left: 'metrics.left', right: 'metrics.right', response: 'metrics.subtract')
        expect(edge_series.series[:values][1]['metrics']['subtract']).to eq(-5)
      end

      it 'handles negative right value correctly' do
        edge_series.transpond.subtract(left: 'metrics.left', right: 'metrics.right', response: 'metrics.subtract')
        expect(edge_series.series[:values][2]['metrics']['subtract']).to eq(20)
      end
    end

    context 'with multiple transponder calls' do
      it 'can apply multiple subtractions to different paths' do
        series.transpond.subtract(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.subtract')
        series.transpond.subtract(left: 'metrics.x', right: 'metrics.y', response: 'metrics.difference')

        first_value = series.series[:values].first
        expect(first_value['requests']).to include('subtract' => 15)
        expect(first_value['metrics']).to include('difference' => 7)
      end

      it 'preserves existing calculated values when adding new ones' do
        series.transpond.subtract(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.subtract')
        original_requests_subtract = series.series[:values].first['requests']['subtract']

        series.transpond.subtract(left: 'metrics.x', right: 'metrics.y', response: 'metrics.subtract')

        expect(series.series[:values].first['requests']['subtract']).to eq(original_requests_subtract)
        expect(series.series[:values].first['metrics']).to include('subtract')
      end
    end
  end

  describe 'integration with Series' do
    it 'is properly registered as subtract transponder' do
      expect(series.transpond).to respond_to(:subtract)
    end

    it 'modifies the series in place' do
      original_object_id = series.series[:values].object_id
      series.transpond.subtract(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.subtract')
      
      expect(series.series[:values]).not_to eq(original_object_id)
      expect(series.series[:values].first['requests']).to include('subtract')
    end

    it 'returns the modified series for chaining' do
      result = series.transpond.subtract(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.subtract')
      expect(result).to eq(series.series)
    end

    it 'can be combined with other series operations' do
      series.transpond.subtract(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.subtract')
      totals = series.aggregate.sum(path: 'requests.subtract')
      
      expect(totals).to eq([67]) # 15 + 17 + 15 + 20
    end
  end
end