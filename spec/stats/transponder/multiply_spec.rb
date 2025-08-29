require 'time'

RSpec.describe Trifle::Stats::Transponder::Multiply do
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
          'requests' => { 'value_a' => 10, 'value_b' => 5 },
          'metrics' => { 'x' => 3, 'y' => 7 }
        },
        { 
          'requests' => { 'value_a' => 15, 'value_b' => 8 },
          'metrics' => { 'x' => 4, 'y' => 6 }
        },
        { 
          'requests' => { 'value_a' => 12, 'value_b' => 3 },
          'metrics' => { 'x' => 2, 'y' => 8 }
        },
        { 
          'requests' => { 'value_a' => 20, 'value_b' => 10 },
          'metrics' => { 'x' => 5, 'y' => 5 }
        }
      ]
    }
  end
  let(:series) { Trifle::Stats::Series.new(series_data) }

  describe '#transpond' do
    context 'with standard parameters' do
      it 'calculates multiplication and adds it to the series data' do
        original_series = series.series.dup
        series.transpond.multiply(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.multiply')

        values = series.series[:values]
        expect(values[0]['requests']['multiply']).to eq(50)
        expect(values[1]['requests']['multiply']).to eq(120)
        expect(values[2]['requests']['multiply']).to eq(36)
        expect(values[3]['requests']['multiply']).to eq(200)

        expect(values[0]['requests']).to include('value_a', 'value_b')
        expect(values[0]['metrics']).not_to have_key('multiply')

        expect(series.series[:at]).to eq(original_series[:at])
      end

      it 'handles different path targets independently' do
        series.transpond.multiply(left: 'metrics.x', right: 'metrics.y', response: 'metrics.multiply')

        values = series.series[:values]
        expect(values[0]['metrics']['multiply']).to eq(21)
        expect(values[1]['metrics']['multiply']).to eq(24)
        expect(values[2]['metrics']['multiply']).to eq(16)
        expect(values[3]['metrics']['multiply']).to eq(25)

        expect(values[0]['metrics']).to include('x', 'y')
        expect(values[0]['requests']).not_to have_key('multiply')
      end
    end

    context 'with custom key name' do
      it 'uses custom key for the calculated multiplication' do
        series.transpond.multiply(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.product')

        expect(series.series[:values].first['requests']['product']).to eq(50)
        expect(series.series[:values].first['requests']).not_to have_key('multiply')
      end

      it 'uses custom left and right field names' do
        custom_series_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'metrics' => { 'first' => 8, 'second' => 6 } }]
        }
        custom_series = Trifle::Stats::Series.new(custom_series_data)

        custom_series.transpond.multiply(left: 'metrics.first', right: 'metrics.second', response: 'metrics.multiply')

        expect(custom_series.series[:values].first['metrics']['multiply']).to eq(48)
      end
    end

    context 'with root path (potential bug scenario)' do
      let(:root_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'left' => 7, 'right' => 8, 'other' => 999 }]
        }
      end
      let(:root_series) { Trifle::Stats::Series.new(root_series_data) }

      it 'handles empty path correctly' do
        root_series.transpond.multiply(left: 'left', right: 'right', response: 'multiply')

        expect(root_series.series[:values].first['multiply']).to eq(56)
        expect(root_series.series[:values].first.keys).to include('left', 'right', 'other', 'multiply')
      end
    end

    context 'with nested paths' do
      let(:nested_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'stats' => { 
              'web' => { 'requests' => { 'value_a' => 12, 'value_b' => 4 } }
            }
          }]
        }
      end
      let(:nested_series) { Trifle::Stats::Series.new(nested_series_data) }

      it 'calculates multiplication for deeply nested paths' do
        nested_series.transpond.multiply(left: 'stats.web.requests.value_a', right: 'stats.web.requests.value_b', response: 'stats.web.requests.multiply')

        expected_value = nested_series.series[:values].first
        expect(expected_value.dig('stats', 'web', 'requests', 'multiply')).to eq(48)
        expect(expected_value.dig('stats', 'web', 'requests', 'value_a')).to eq(12)
        expect(expected_value.dig('stats', 'web', 'requests', 'value_b')).to eq(4)
      end

      it 'handles nested left and right field paths' do
        complex_nested_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'metrics' => { 
              'left_values' => { 'amount' => 9 },
              'right_values' => { 'amount' => 3 }
            }
          }]
        }
        complex_series = Trifle::Stats::Series.new(complex_nested_data)

        complex_series.transpond.multiply(
          left: 'metrics.left_values.amount', 
          right: 'metrics.right_values.amount',
          response: 'metrics.multiply'
        )

        expect(complex_series.series[:values].first.dig('metrics', 'multiply')).to eq(27)
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
            { 'requests' => { 'value_a' => 10, 'value_b' => 5 } },
            { 'requests' => { 'value_a' => 15 } }, # Missing right value
            { 'requests' => { 'value_b' => 3 } }  # Missing left value
          ]
        }
      end
      let(:incomplete_series) { Trifle::Stats::Series.new(incomplete_series_data) }

      it 'skips calculation when left value is missing' do
        incomplete_series.transpond.multiply(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.multiply')

        expect(incomplete_series.series[:values]).to eq([
          { 'requests' => { 'value_a' => 10, 'value_b' => 5, 'multiply' => 50 } },
          { 'requests' => { 'value_a' => 15 } }, # Unchanged - no right value
          { 'requests' => { 'value_b' => 3 } }  # Unchanged - no left value
        ])
      end

      it 'skips calculation when right value is missing' do
        incomplete_series.transpond.multiply(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.multiply')

        values = incomplete_series.series[:values]
        expect(values[1]).not_to have_key('multiply')
        expect(values[2]).not_to have_key('multiply')
      end

      it 'handles completely missing path gracefully' do
        incomplete_series.transpond.multiply(left: 'nonexistent.value_a', right: 'nonexistent.value_b', response: 'nonexistent.multiply')

        expect(incomplete_series.series[:values]).to eq([
          { 'requests' => { 'value_a' => 10, 'value_b' => 5 } },
          { 'requests' => { 'value_a' => 15 } },
          { 'requests' => { 'value_b' => 3 } }
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
            { 'metrics' => { 'left' => 0, 'right' => 5 } },      # Zero left
            { 'metrics' => { 'left' => 10, 'right' => 0 } },     # Zero right
            { 'metrics' => { 'left' => -4, 'right' => 3 } }      # Negative left
          ]
        }
      end
      let(:edge_series) { Trifle::Stats::Series.new(edge_case_data) }

      it 'handles zero left value correctly' do
        edge_series.transpond.multiply(left: 'metrics.left', right: 'metrics.right', response: 'metrics.multiply')
        expect(edge_series.series[:values][0]['metrics']['multiply']).to eq(0)
      end

      it 'handles zero right value correctly' do
        edge_series.transpond.multiply(left: 'metrics.left', right: 'metrics.right', response: 'metrics.multiply')
        expect(edge_series.series[:values][1]['metrics']['multiply']).to eq(0)
      end

      it 'handles negative values correctly' do
        edge_series.transpond.multiply(left: 'metrics.left', right: 'metrics.right', response: 'metrics.multiply')
        expect(edge_series.series[:values][2]['metrics']['multiply']).to eq(-12)
      end
    end

    context 'with multiple transponder calls' do
      it 'can apply multiple multiplications to different paths' do
        series.transpond.multiply(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.multiply')
        series.transpond.multiply(left: 'metrics.x', right: 'metrics.y', response: 'metrics.product')

        first_value = series.series[:values].first
        expect(first_value['requests']).to include('multiply' => 50)
        expect(first_value['metrics']).to include('product' => 21)
      end

      it 'preserves existing calculated values when adding new ones' do
        series.transpond.multiply(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.multiply')
        original_requests_multiply = series.series[:values].first['requests']['multiply']

        series.transpond.multiply(left: 'metrics.x', right: 'metrics.y', response: 'metrics.multiply')

        expect(series.series[:values].first['requests']['multiply']).to eq(original_requests_multiply)
        expect(series.series[:values].first['metrics']).to include('multiply')
      end
    end
  end

  describe 'integration with Series' do
    it 'is properly registered as multiply transponder' do
      expect(series.transpond).to respond_to(:multiply)
    end

    it 'modifies the series in place' do
      original_object_id = series.series[:values].object_id
      series.transpond.multiply(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.multiply')
      
      expect(series.series[:values]).not_to eq(original_object_id)
      expect(series.series[:values].first['requests']).to include('multiply')
    end

    it 'returns the modified series for chaining' do
      result = series.transpond.multiply(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.multiply')
      expect(result).to eq(series.series)
    end

    it 'can be combined with other series operations' do
      series.transpond.multiply(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.multiply')
      totals = series.aggregate.sum(path: 'requests.multiply')
      
      expect(totals).to eq([406]) # 50 + 120 + 36 + 200
    end
  end
end