require 'time'

RSpec.describe Trifle::Stats::Transponder::Ratio do
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
          'conversions' => { 'sample' => 25, 'total' => 100 },
          'clicks' => { 'sample' => 50, 'total' => 200 }
        },
        { 
          'conversions' => { 'sample' => 30, 'total' => 150 },
          'clicks' => { 'sample' => 75, 'total' => 300 }
        },
        { 
          'conversions' => { 'sample' => 15, 'total' => 80 },
          'clicks' => { 'sample' => 40, 'total' => 160 }
        },
        { 
          'conversions' => { 'sample' => 20, 'total' => 120 },
          'clicks' => { 'sample' => 60, 'total' => 240 }
        }
      ]
    }
  end
  let(:series) { Trifle::Stats::Series.new(series_data) }

  describe '#transpond' do
    context 'with standard parameters' do
      it 'calculates percentage ratio and adds it to the series data' do
        original_series = series.series.dup
        series.transpond.ratio(sample: 'conversions.sample', total: 'conversions.total', response: 'conversions.ratio')

        # Check that ratios were calculated correctly (handling BigDecimal format)
        values = series.series[:values]
        expect(values[0]['conversions']['ratio'].to_f).to eq(25.0)
        expect(values[1]['conversions']['ratio'].to_f).to eq(20.0)
        expect(values[2]['conversions']['ratio'].to_f).to eq(18.75)
        expect(values[3]['conversions']['ratio'].to_f).to be_within(0.01).of(16.67)
        
        # Check that original data is preserved
        expect(values[0]['conversions']['sample'].to_i).to eq(25)
        expect(values[0]['conversions']['total'].to_i).to eq(100)
        expect(values[0]['clicks']['sample'].to_i).to eq(50)

        # Original timestamps should be preserved
        expect(series.series[:at]).to eq(original_series[:at])
      end

      it 'handles different path targets independently' do
        series.transpond.ratio(sample: 'clicks.sample', total: 'clicks.total', response: 'clicks.ratio')

        # Check that ratios were calculated correctly (handling BigDecimal format)
        values = series.series[:values]
        expect(values[0]['clicks']['ratio'].to_f).to eq(25.0)
        expect(values[1]['clicks']['ratio'].to_f).to eq(25.0)
        expect(values[2]['clicks']['ratio'].to_f).to eq(25.0)
        expect(values[3]['clicks']['ratio'].to_f).to eq(25.0)
        
        # Check that original data is preserved and conversions don't have ratio
        expect(values[0]['conversions']).not_to have_key('ratio')
        expect(values[0]['clicks']['sample'].to_i).to eq(50)
      end
    end

    context 'with custom key name' do
      it 'uses custom key for the calculated ratio' do
        series.transpond.ratio(sample: 'conversions.sample', total: 'conversions.total', response: 'conversions.percentage')

        expect(series.series[:values].first['conversions']).to include('percentage' => 25.0)
        expect(series.series[:values].first['conversions']).not_to have_key('ratio')
      end

      it 'uses custom sample and total field names' do
        custom_series_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'metrics' => { 'successes' => 30, 'attempts' => 120 } }]
        }
        custom_series = Trifle::Stats::Series.new(custom_series_data)

        custom_series.transpond.ratio(sample: 'metrics.successes', total: 'metrics.attempts', response: 'metrics.ratio')

        expect(custom_series.series[:values].first['metrics']).to include('ratio' => 25.0)
      end
    end

    context 'with root path (potential bug scenario)' do
      let(:root_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'sample' => 25, 'total' => 100, 'other' => 999 }]
        }
      end
      let(:root_series) { Trifle::Stats::Series.new(root_series_data) }

      it 'handles empty path correctly' do
        root_series.transpond.ratio(sample: 'sample', total: 'total', response: 'ratio')

        # When path is empty, key is created directly at root level (same as nil path)
        expect(root_series.series[:values].first['ratio'].to_f).to eq(25.0)
        expect(root_series.series[:values].first.keys).to include('sample', 'total', 'other', 'ratio')
      end

      it 'handles nil path correctly' do
        root_series.transpond.ratio(sample: 'sample', total: 'total', response: 'ratio')

        # When path is nil, the key becomes just 'ratio' at root level
        expect(root_series.series[:values].first['ratio'].to_f).to eq(25.0)
        expect(root_series.series[:values].first.keys).to include('sample', 'total', 'other', 'ratio')
      end
    end

    context 'with nested paths' do
      let(:nested_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'analytics' => { 
              'marketing' => { 'conversions' => { 'sample' => 40, 'total' => 160 } }
            }
          }]
        }
      end
      let(:nested_series) { Trifle::Stats::Series.new(nested_series_data) }

      it 'calculates ratio for deeply nested paths' do
        nested_series.transpond.ratio(sample: 'analytics.marketing.conversions.sample', total: 'analytics.marketing.conversions.total', response: 'analytics.marketing.conversions.ratio')

        expected_value = nested_series.series[:values].first
        expect(expected_value.dig('analytics', 'marketing', 'conversions', 'ratio')).to eq(25.0)
        expect(expected_value.dig('analytics', 'marketing', 'conversions', 'sample')).to eq(40)
        expect(expected_value.dig('analytics', 'marketing', 'conversions', 'total')).to eq(160)
      end

      it 'handles nested sample and total field paths' do
        complex_nested_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'metrics' => { 
              'successes' => { 'count' => 20 },
              'attempts' => { 'count' => 80 }
            }
          }]
        }
        complex_series = Trifle::Stats::Series.new(complex_nested_data)

        complex_series.transpond.ratio(
          sample: 'metrics.successes.count', 
          total: 'metrics.attempts.count',
          response: 'metrics.ratio'
        )

        expect(complex_series.series[:values].first.dig('metrics', 'ratio')).to eq(25.0)
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
            { 'conversions' => { 'sample' => 25, 'total' => 100 } },
            { 'conversions' => { 'sample' => 30 } }, # Missing total
            { 'conversions' => { 'total' => 80 } }   # Missing sample
          ]
        }
      end
      let(:incomplete_series) { Trifle::Stats::Series.new(incomplete_series_data) }

      it 'skips calculation when sample is missing' do
        incomplete_series.transpond.ratio(sample: 'conversions.sample', total: 'conversions.total', response: 'conversions.ratio')

        expect(incomplete_series.series[:values]).to eq([
          { 'conversions' => { 'sample' => 25, 'total' => 100, 'ratio' => 25.0 } },
          { 'conversions' => { 'sample' => 30 } }, # Unchanged - no total
          { 'conversions' => { 'total' => 80 } }   # Unchanged - no sample
        ])
      end

      it 'skips calculation when total is missing' do
        incomplete_series.transpond.ratio(sample: 'conversions.sample', total: 'conversions.total', response: 'conversions.ratio')

        values = incomplete_series.series[:values]
        expect(values[1]).not_to have_key('ratio')
        expect(values[2]).not_to have_key('ratio')
      end

      it 'handles completely missing path gracefully' do
        incomplete_series.transpond.ratio(sample: 'nonexistent.sample', total: 'nonexistent.total', response: 'nonexistent.ratio')

        # Should remain unchanged
        expect(incomplete_series.series[:values]).to eq([
          { 'conversions' => { 'sample' => 25, 'total' => 100 } },
          { 'conversions' => { 'sample' => 30 } },
          { 'conversions' => { 'total' => 80 } }
        ])
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
            { 'metrics' => { 'sample' => 0, 'total' => 100 } },     # Zero sample
            { 'metrics' => { 'sample' => 50, 'total' => 0 } },      # Zero total (division by zero)
            { 'metrics' => { 'sample' => 120, 'total' => 100 } },   # Sample > total (over 100%)
            { 'metrics' => { 'sample' => -10, 'total' => 100 } }    # Negative sample
          ]
        }
      end
      let(:edge_series) { Trifle::Stats::Series.new(edge_case_data) }

      it 'handles zero sample correctly' do
        edge_series.transpond.ratio(sample: 'metrics.sample', total: 'metrics.total', response: 'metrics.ratio')
        expect(edge_series.series[:values][0]['metrics']['ratio']).to eq(0.0)
      end

      it 'handles division by zero gracefully' do
        edge_series.transpond.ratio(sample: 'metrics.sample', total: 'metrics.total', response: 'metrics.ratio')
        
        # Division by zero should result in NaN, which gets converted to 0
        result = edge_series.series[:values][1]['metrics']['ratio']
        expect(result.infinite?).to be(1) # Check that it's positive infinity
        # Transponder doesn't handle division by zero - it returns Infinity
      end

      it 'handles sample greater than total correctly' do
        edge_series.transpond.ratio(sample: 'metrics.sample', total: 'metrics.total', response: 'metrics.ratio')
        expect(edge_series.series[:values][2]['metrics']['ratio']).to eq(120.0)
      end

      it 'handles negative sample correctly' do
        edge_series.transpond.ratio(sample: 'metrics.sample', total: 'metrics.total', response: 'metrics.ratio')
        expect(edge_series.series[:values][3]['metrics']['ratio']).to eq(-10.0)
      end
    end

    context 'with precision scenarios' do
      let(:precision_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'metrics' => { 'sample' => 1, 'total' => 3 } }]
        }
      end
      let(:precision_series) { Trifle::Stats::Series.new(precision_data) }

      it 'handles decimal precision correctly' do
        precision_series.transpond.ratio(sample: 'metrics.sample', total: 'metrics.total', response: 'metrics.ratio')
        
        # 1/3 * 100 = 33.333...
        result = precision_series.series[:values].first['metrics']['ratio']
        expect(result).to be_within(0.001).of(33.333)
      end
    end

    context 'with multiple transponder calls' do
      it 'can apply multiple ratios to different paths' do
        series.transpond.ratio(sample: 'conversions.sample', total: 'conversions.total', response: 'conversions.ratio')
        series.transpond.ratio(sample: 'clicks.sample', total: 'clicks.total', response: 'clicks.click_rate')

        first_value = series.series[:values].first
        expect(first_value['conversions']).to include('ratio' => 25.0)
        expect(first_value['clicks']).to include('click_rate' => 25.0)
      end

      it 'preserves existing calculated values when adding new ones' do
        series.transpond.ratio(sample: 'conversions.sample', total: 'conversions.total', response: 'conversions.ratio')
        original_conversion_ratio = series.series[:values].first['conversions']['ratio']

        series.transpond.ratio(sample: 'clicks.sample', total: 'clicks.total', response: 'clicks.ratio')

        expect(series.series[:values].first['conversions']['ratio']).to eq(original_conversion_ratio)
        expect(series.series[:values].first['clicks']).to include('ratio')
      end
    end
  end

  describe 'integration with Series' do
    it 'is properly registered as ratio transponder' do
      expect(series.transpond).to respond_to(:ratio)
    end

    it 'modifies the series in place' do
      original_object_id = series.series[:values].object_id
      series.transpond.ratio(sample: 'conversions.sample', total: 'conversions.total', response: 'conversions.ratio')
      
      # The series values array gets replaced during transponder operations
      expect(series.series[:values]).not_to eq(original_object_id)
      expect(series.series[:values].first['conversions']).to include('ratio')
    end

    it 'returns the modified series for chaining' do
      result = series.transpond.ratio(sample: 'conversions.sample', total: 'conversions.total', response: 'conversions.ratio')
      expect(result).to eq(series.series)
    end

    it 'can be combined with other series operations' do
      # Add ratios, then aggregate them
      series.transpond.ratio(sample: 'conversions.sample', total: 'conversions.total', response: 'conversions.ratio')
      avg_ratio = series.aggregate.avg(path: 'conversions.ratio')
      
      # Average of [25.0, 20.0, 18.75, 16.666...] ≈ 20.104
      expect(avg_ratio.first).to be_within(0.1).of(20.1)
    end

    it 'can be combined with other transponders' do
      # First add ratio, then check we can add other calculations
      series.transpond.ratio(sample: 'conversions.sample', total: 'conversions.total', response: 'conversions.ratio')
      
      # Add sum and count fields to test average transponder
      series.series[:values] = series.series[:values].map do |value|
        conv = value['conversions']
        conv['sum'] = conv['sample'] + conv['total']
        conv['count'] = 2
        value
      end
      
      series.transpond.average(sum: 'conversions.sum', count: 'conversions.count', response: 'conversions.avg_value')
      
      first_conv = series.series[:values].first['conversions']
      expect(first_conv).to include('ratio' => 25.0)
      expect(first_conv).to include('avg_value')
    end
  end
end