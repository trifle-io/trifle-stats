require 'time'

RSpec.describe Trifle::Stats::Transponder::Add do
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
      it 'calculates addition and adds it to the series data' do
        original_series = series.series.dup
        series.transpond.add(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.add')

        values = series.series[:values]
        expect(values[0]['requests']['add']).to eq(15)
        expect(values[1]['requests']['add']).to eq(23)
        expect(values[2]['requests']['add']).to eq(15)
        expect(values[3]['requests']['add']).to eq(30)

        expect(values[0]['requests']).to include('value_a', 'value_b')
        expect(values[0]['metrics']).not_to have_key('add')

        expect(series.series[:at]).to eq(original_series[:at])
      end

      it 'handles different path targets independently' do
        series.transpond.add(left: 'metrics.x', right: 'metrics.y', response: 'metrics.add')

        values = series.series[:values]
        expect(values[0]['metrics']['add']).to eq(10)
        expect(values[1]['metrics']['add']).to eq(10)
        expect(values[2]['metrics']['add']).to eq(10)
        expect(values[3]['metrics']['add']).to eq(10)

        expect(values[0]['metrics']).to include('x', 'y')
        expect(values[0]['requests']).not_to have_key('add')
      end
    end

    context 'with custom key name' do
      it 'uses custom key for the calculated addition' do
        series.transpond.add(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.total')

        expect(series.series[:values].first['requests']['total']).to eq(15)
        expect(series.series[:values].first['requests']).not_to have_key('add')
      end

      it 'uses custom left and right field names' do
        custom_series_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'metrics' => { 'first' => 25, 'second' => 15 } }]
        }
        custom_series = Trifle::Stats::Series.new(custom_series_data)

        custom_series.transpond.add(left: 'metrics.first', right: 'metrics.second', response: 'metrics.add')

        expect(custom_series.series[:values].first['metrics']['add']).to eq(40)
      end
    end

    context 'with root path (potential bug scenario)' do
      let(:root_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'left' => 50, 'right' => 25, 'other' => 999 }]
        }
      end
      let(:root_series) { Trifle::Stats::Series.new(root_series_data) }

      it 'handles empty path correctly' do
        root_series.transpond.add(left: 'left', right: 'right', response: 'add')

        expect(root_series.series[:values].first['add']).to eq(75)
        expect(root_series.series[:values].first.keys).to include('left', 'right', 'other', 'add')
      end
    end

    context 'with nested paths' do
      let(:nested_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'stats' => { 
              'web' => { 'requests' => { 'value_a' => 100, 'value_b' => 50 } }
            }
          }]
        }
      end
      let(:nested_series) { Trifle::Stats::Series.new(nested_series_data) }

      it 'calculates addition for deeply nested paths' do
        nested_series.transpond.add(left: 'stats.web.requests.value_a', right: 'stats.web.requests.value_b', response: 'stats.web.requests.add')

        expected_value = nested_series.series[:values].first
        expect(expected_value.dig('stats', 'web', 'requests', 'add')).to eq(150)
        expect(expected_value.dig('stats', 'web', 'requests', 'value_a')).to eq(100)
        expect(expected_value.dig('stats', 'web', 'requests', 'value_b')).to eq(50)
      end

      it 'handles nested left and right field paths' do
        complex_nested_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'metrics' => { 
              'left_values' => { 'amount' => 75 },
              'right_values' => { 'amount' => 25 }
            }
          }]
        }
        complex_series = Trifle::Stats::Series.new(complex_nested_data)

        complex_series.transpond.add(
          left: 'metrics.left_values.amount', 
          right: 'metrics.right_values.amount',
          response: 'metrics.add'
        )

        expect(complex_series.series[:values].first.dig('metrics', 'add')).to eq(100)
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
        incomplete_series.transpond.add(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.add')

        expect(incomplete_series.series[:values]).to eq([
          { 'requests' => { 'value_a' => 10, 'value_b' => 5, 'add' => 15 } },
          { 'requests' => { 'value_a' => 15 } }, # Unchanged - no right value
          { 'requests' => { 'value_b' => 3 } }  # Unchanged - no left value
        ])
      end

      it 'skips calculation when right value is missing' do
        incomplete_series.transpond.add(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.add')

        values = incomplete_series.series[:values]
        expect(values[1]).not_to have_key('add')
        expect(values[2]).not_to have_key('add')
      end

      it 'handles completely missing path gracefully' do
        incomplete_series.transpond.add(left: 'nonexistent.value_a', right: 'nonexistent.value_b', response: 'nonexistent.add')

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
            { 'metrics' => { 'left' => -10, 'right' => 15 } }    # Negative left
          ]
        }
      end
      let(:edge_series) { Trifle::Stats::Series.new(edge_case_data) }

      it 'handles zero left value correctly' do
        edge_series.transpond.add(left: 'metrics.left', right: 'metrics.right', response: 'metrics.add')
        expect(edge_series.series[:values][0]['metrics']['add']).to eq(5)
      end

      it 'handles zero right value correctly' do
        edge_series.transpond.add(left: 'metrics.left', right: 'metrics.right', response: 'metrics.add')
        expect(edge_series.series[:values][1]['metrics']['add']).to eq(10)
      end

      it 'handles negative values correctly' do
        edge_series.transpond.add(left: 'metrics.left', right: 'metrics.right', response: 'metrics.add')
        expect(edge_series.series[:values][2]['metrics']['add']).to eq(5)
      end
    end

    context 'with multiple transponder calls' do
      it 'can apply multiple additions to different paths' do
        series.transpond.add(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.add')
        series.transpond.add(left: 'metrics.x', right: 'metrics.y', response: 'metrics.total')

        first_value = series.series[:values].first
        expect(first_value['requests']).to include('add' => 15)
        expect(first_value['metrics']).to include('total' => 10)
      end

      it 'preserves existing calculated values when adding new ones' do
        series.transpond.add(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.add')
        original_requests_add = series.series[:values].first['requests']['add']

        series.transpond.add(left: 'metrics.x', right: 'metrics.y', response: 'metrics.add')

        expect(series.series[:values].first['requests']['add']).to eq(original_requests_add)
        expect(series.series[:values].first['metrics']).to include('add')
      end
    end
  end

  describe 'integration with Series' do
    it 'is properly registered as add transponder' do
      expect(series.transpond).to respond_to(:add)
    end

    it 'modifies the series in place' do
      original_object_id = series.series[:values].object_id
      series.transpond.add(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.add')
      
      expect(series.series[:values]).not_to eq(original_object_id)
      expect(series.series[:values].first['requests']).to include('add')
    end

    it 'returns the modified series for chaining' do
      result = series.transpond.add(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.add')
      expect(result).to eq(series.series)
    end

    it 'can be combined with other series operations' do
      series.transpond.add(left: 'requests.value_a', right: 'requests.value_b', response: 'requests.add')
      totals = series.aggregate.sum(path: 'requests.add')
      
      expect(totals).to eq([83]) # 15 + 23 + 15 + 30
    end
  end
end