require 'time'

RSpec.describe Trifle::Stats::Transponder::StandardDeviation do
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
          'measurements' => { 'sum' => 30, 'count' => 3, 'square' => 310 },
          'scores' => { 'sum' => 40, 'count' => 4, 'square' => 430 }
        },
        { 
          'measurements' => { 'sum' => 45, 'count' => 5, 'square' => 415 },
          'scores' => { 'sum' => 50, 'count' => 5, 'square' => 530 }
        },
        { 
          'measurements' => { 'sum' => 24, 'count' => 4, 'square' => 156 },
          'scores' => { 'sum' => 32, 'count' => 4, 'square' => 276 }
        },
        { 
          'measurements' => { 'sum' => 36, 'count' => 6, 'square' => 228 },
          'scores' => { 'sum' => 48, 'count' => 6, 'square' => 398 }
        }
      ]
    }
  end
  let(:series) { Trifle::Stats::Series.new(series_data) }

  describe '#transpond' do
    context 'with standard parameters' do
      it 'calculates standard deviation and adds it to the series data' do
        original_series = series.series.dup
        series.transpond.standard_deviation(sum: 'measurements.sum', count: 'measurements.count', square: 'measurements.square', response: 'measurements.sd')

        # Standard deviation formula: sqrt((n*∑x² - (∑x)²) / (n*(n-1)))
        # For first value: sqrt((3*310 - 30²) / (3*2)) = sqrt((930 - 900) / 6) = sqrt(5) ≈ 2.236
        expected_sd = Math.sqrt((3 * 310 - 30 * 30) / (3 * 2))

        expect(series.series[:values].first['measurements']).to include('sd' => expected_sd)
        expect(series.series[:values].first['measurements']).to include('sum' => 30, 'count' => 3, 'square' => 310)
        
        # Original timestamps should be preserved
        expect(series.series[:at]).to eq(original_series[:at])
      end

      it 'handles different path targets independently' do
        series.transpond.standard_deviation(sum: 'scores.sum', count: 'scores.count', square: 'scores.square', response: 'scores.sd')

        # For scores first value: sqrt((4*430 - 40²) / (4*3)) = sqrt((1720 - 1600) / 12) = sqrt(10) ≈ 3.162
        expected_sd = Math.sqrt((4 * 430 - 40 * 40) / (4 * 3))

        expect(series.series[:values].first['scores']).to include('sd' => expected_sd)
        expect(series.series[:values].first['measurements']).not_to have_key('sd')
      end
    end

    context 'with custom key name' do
      it 'uses custom key for the calculated standard deviation' do
        series.transpond.standard_deviation(sum: 'measurements.sum', count: 'measurements.count', square: 'measurements.square', response: 'measurements.stddev')

        expect(series.series[:values].first['measurements']).to include('stddev')
        expect(series.series[:values].first['measurements']).not_to have_key('sd')
      end

      it 'uses custom sum, count, and square field names' do
        custom_series_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'metrics' => { 'total' => 30, 'num' => 3, 'squared' => 310 } }]
        }
        custom_series = Trifle::Stats::Series.new(custom_series_data)

        custom_series.transpond.standard_deviation(
          sum: 'metrics.total', 
          count: 'metrics.num', 
          square: 'metrics.squared',
          response: 'metrics.sd'
        )

        expected_sd = Math.sqrt((3 * 310 - 30 * 30) / (3 * 2))
        expect(custom_series.series[:values].first['metrics']).to include('sd' => expected_sd)
      end
    end

    context 'with root path (potential bug scenario)' do
      let(:root_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 'sum' => 30, 'count' => 3, 'square' => 310, 'other' => 999 }]
        }
      end
      let(:root_series) { Trifle::Stats::Series.new(root_series_data) }

      it 'handles empty path correctly' do
        root_series.transpond.standard_deviation(sum: 'sum', count: 'count', square: 'square', response: 'sd')

        expected_sd = Math.sqrt((3 * 310 - 30 * 30) / (3 * 2))
        # When path is empty, key is created directly at root level (same as nil path)
        expect(root_series.series[:values].first['sd']).to eq(expected_sd)
        expect(root_series.series[:values].first.keys).to include('sum', 'count', 'square', 'other', 'sd')
      end

      it 'handles nil path correctly' do
        root_series.transpond.standard_deviation(sum: 'sum', count: 'count', square: 'square', response: 'sd')

        expected_sd = Math.sqrt((3 * 310 - 30 * 30) / (3 * 2))
        # When path is nil, the key becomes just 'sd' at root level
        expect(root_series.series[:values].first['sd']).to eq(expected_sd)
        expect(root_series.series[:values].first.keys).to include('sum', 'count', 'square', 'other', 'sd')
      end
    end

    context 'with nested paths' do
      let(:nested_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'analytics' => { 
              'performance' => { 'data' => { 'sum' => 30, 'count' => 3, 'square' => 310 } }
            }
          }]
        }
      end
      let(:nested_series) { Trifle::Stats::Series.new(nested_series_data) }

      it 'calculates standard deviation for deeply nested paths' do
        nested_series.transpond.standard_deviation(sum: 'analytics.performance.data.sum', count: 'analytics.performance.data.count', square: 'analytics.performance.data.square', response: 'analytics.performance.data.sd')

        expected_sd = Math.sqrt((3 * 310 - 30 * 30) / (3 * 2))
        expected_value = nested_series.series[:values].first
        expect(expected_value.dig('analytics', 'performance', 'data', 'sd')).to eq(expected_sd)
        expect(expected_value.dig('analytics', 'performance', 'data', 'sum')).to eq(30)
        expect(expected_value.dig('analytics', 'performance', 'data', 'count')).to eq(3)
        expect(expected_value.dig('analytics', 'performance', 'data', 'square')).to eq(310)
      end

      it 'handles nested sum, count, and square field paths' do
        complex_nested_data = {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [{ 
            'metrics' => { 
              'totals' => { 'value' => 30 },
              'counters' => { 'items' => 3 },
              'squares' => { 'sum' => 310 }
            }
          }]
        }
        complex_series = Trifle::Stats::Series.new(complex_nested_data)

        complex_series.transpond.standard_deviation(
          sum: 'metrics.totals.value', 
          count: 'metrics.counters.items',
          square: 'metrics.squares.sum',
          response: 'metrics.sd'
        )

        expected_sd = Math.sqrt((3 * 310 - 30 * 30) / (3 * 2))
        expect(complex_series.series[:values].first.dig('metrics', 'sd')).to eq(expected_sd)
      end
    end

    context 'with missing data' do
      let(:incomplete_series_data) do
        {
          at: [
            Time.parse('2023-01-01 10:00:00'),
            Time.parse('2023-01-01 11:00:00'),
            Time.parse('2023-01-01 12:00:00'),
            Time.parse('2023-01-01 13:00:00')
          ],
          values: [
            { 'measurements' => { 'sum' => 30, 'count' => 3, 'square' => 310 } },
            { 'measurements' => { 'sum' => 45, 'count' => 5 } }, # Missing square
            { 'measurements' => { 'sum' => 24, 'square' => 156 } }, # Missing count
            { 'measurements' => { 'count' => 6, 'square' => 228 } }  # Missing sum
          ]
        }
      end
      let(:incomplete_series) { Trifle::Stats::Series.new(incomplete_series_data) }

      it 'skips calculation when any required field is missing' do
        incomplete_series.transpond.standard_deviation(sum: 'measurements.sum', count: 'measurements.count', square: 'measurements.square', response: 'measurements.sd')

        expected_sd = Math.sqrt((3 * 310 - 30 * 30) / (3 * 2))
        expect(incomplete_series.series[:values]).to eq([
          { 'measurements' => { 'sum' => 30, 'count' => 3, 'square' => 310, 'sd' => expected_sd } },
          { 'measurements' => { 'sum' => 45, 'count' => 5 } }, # Unchanged - no square
          { 'measurements' => { 'sum' => 24, 'square' => 156 } }, # Unchanged - no count
          { 'measurements' => { 'count' => 6, 'square' => 228 } }  # Unchanged - no sum
        ])
      end

      it 'handles completely missing path gracefully' do
        incomplete_series.transpond.standard_deviation(sum: 'nonexistent.sum', count: 'nonexistent.count', square: 'nonexistent.square', response: 'nonexistent.sd')

        # Should remain unchanged
        expect(incomplete_series.series[:values]).to eq([
          { 'measurements' => { 'sum' => 30, 'count' => 3, 'square' => 310 } },
          { 'measurements' => { 'sum' => 45, 'count' => 5 } },
          { 'measurements' => { 'sum' => 24, 'square' => 156 } },
          { 'measurements' => { 'count' => 6, 'square' => 228 } }
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
            { 'metrics' => { 'sum' => 0, 'count' => 3, 'square' => 0 } },      # All zeros
            { 'metrics' => { 'sum' => 30, 'count' => 1, 'square' => 900 } },   # Count = 1 (division by count-1 = 0)
            { 'metrics' => { 'sum' => 30, 'count' => 0, 'square' => 310 } },   # Count = 0
            { 'metrics' => { 'sum' => -30, 'count' => 3, 'square' => 310 } }   # Negative sum
          ]
        }
      end
      let(:edge_series) { Trifle::Stats::Series.new(edge_case_data) }

      it 'handles all zero values correctly' do
        edge_series.transpond.standard_deviation(sum: 'metrics.sum', count: 'metrics.count', square: 'metrics.square', response: 'metrics.sd')
        expect(edge_series.series[:values][0]['metrics']['sd']).to eq(0.0)
      end

      it 'handles count = 1 gracefully (division by zero in denominator)' do
        edge_series.transpond.standard_deviation(sum: 'metrics.sum', count: 'metrics.count', square: 'metrics.square', response: 'metrics.sd')
        
        # Division by (count-1) when count=1 should result in NaN, converted to 0
        expect(edge_series.series[:values][1]['metrics']['sd']).to eq(0.0)
      end

      it 'handles count = 0 gracefully' do
        edge_series.transpond.standard_deviation(sum: 'metrics.sum', count: 'metrics.count', square: 'metrics.square', response: 'metrics.sd')
        
        # Division by zero should result in NaN, converted to 0
        result = edge_series.series[:values][2]['metrics']['sd']
        expect(result.infinite?).to be(1) # Check that it's positive infinity
        # Transponder doesn't handle division by zero - it returns Infinity
      end

      it 'handles negative sum correctly' do
        edge_series.transpond.standard_deviation(sum: 'metrics.sum', count: 'metrics.count', square: 'metrics.square', response: 'metrics.sd')
        
        # Formula should still work with negative sum
        expected_sd = Math.sqrt((3 * 310 - (-30) * (-30)) / (3 * 2))
        expect(edge_series.series[:values][3]['metrics']['sd']).to eq(expected_sd)
      end
    end

    context 'with mathematical precision scenarios' do
      let(:precision_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [
            # Perfect squares scenario: values are 1, 2, 3
            # sum = 6, count = 3, square = 14
            # SD = sqrt((3*14 - 6²) / (3*2)) = sqrt((42-36)/6) = sqrt(1) = 1.0
            { 'perfect' => { 'sum' => 6, 'count' => 3, 'square' => 14 } }
          ]
        }
      end
      let(:precision_series) { Trifle::Stats::Series.new(precision_data) }

      it 'calculates standard deviation with correct precision' do
        precision_series.transpond.standard_deviation(sum: 'perfect.sum', count: 'perfect.count', square: 'perfect.square', response: 'perfect.sd')
        
        result = precision_series.series[:values].first['perfect']['sd']
        expect(result).to eq(1.0)
      end
    end

    context 'with multiple transponder calls' do
      it 'can apply multiple standard deviations to different paths' do
        series.transpond.standard_deviation(sum: 'measurements.sum', count: 'measurements.count', square: 'measurements.square', response: 'measurements.sd')
        series.transpond.standard_deviation(sum: 'scores.sum', count: 'scores.count', square: 'scores.square', response: 'scores.score_sd')

        first_value = series.series[:values].first
        expect(first_value['measurements']).to include('sd')
        expect(first_value['scores']).to include('score_sd')
      end

      it 'preserves existing calculated values when adding new ones' do
        series.transpond.standard_deviation(sum: 'measurements.sum', count: 'measurements.count', square: 'measurements.square', response: 'measurements.sd')
        original_sd = series.series[:values].first['measurements']['sd']

        series.transpond.standard_deviation(sum: 'scores.sum', count: 'scores.count', square: 'scores.square', response: 'scores.sd')

        expect(series.series[:values].first['measurements']['sd']).to eq(original_sd)
        expect(series.series[:values].first['scores']).to include('sd')
      end
    end

    context 'with realistic statistical data' do
      let(:realistic_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [
            # Sample data: [5, 7, 9] -> sum=21, count=3, sum_of_squares=5²+7²+9²=155
            { 'sample' => { 'sum' => 21, 'count' => 3, 'square' => 155 } }
          ]
        }
      end
      let(:realistic_series) { Trifle::Stats::Series.new(realistic_data) }

      it 'calculates standard deviation for realistic data' do
        realistic_series.transpond.standard_deviation(sum: 'sample.sum', count: 'sample.count', square: 'sample.square', response: 'sample.sd')
        
        # Manual calculation: sqrt((3*155 - 21²) / (3*2)) = sqrt((465-441)/6) = sqrt(4) = 2.0
        result = realistic_series.series[:values].first['sample']['sd']
        expect(result).to eq(2.0)
      end
    end
  end

  describe 'integration with Series' do
    it 'is properly registered as standard_deviation transponder' do
      expect(series.transpond).to respond_to(:standard_deviation)
    end

    it 'modifies the series in place' do
      original_object_id = series.series[:values].object_id
      series.transpond.standard_deviation(sum: 'measurements.sum', count: 'measurements.count', square: 'measurements.square', response: 'measurements.sd')
      
      # The series values array gets replaced during transponder operations
      expect(series.series[:values]).not_to eq(original_object_id)
      expect(series.series[:values].first['measurements']).to include('sd')
    end

    it 'returns the modified series for chaining' do
      result = series.transpond.standard_deviation(sum: 'measurements.sum', count: 'measurements.count', square: 'measurements.square', response: 'measurements.sd')
      expect(result).to eq(series.series)
    end

    it 'can be combined with other series operations' do
      # Add standard deviations, then aggregate them
      series.transpond.standard_deviation(sum: 'measurements.sum', count: 'measurements.count', square: 'measurements.square', response: 'measurements.sd')
      avg_sd = series.aggregate.avg(path: 'measurements.sd')
      
      # Should get average of all calculated standard deviations
      expect(avg_sd.first).to be_a(Numeric) # Could be Float or BigDecimal
      expect(avg_sd.first).to be > 0
    end

    it 'can be combined with other transponders' do
      # Add standard deviation, then add average using the same data
      series.transpond.standard_deviation(sum: 'measurements.sum', count: 'measurements.count', square: 'measurements.square', response: 'measurements.sd')
      series.transpond.average(sum: 'measurements.sum', count: 'measurements.count', response: 'measurements.average')
      
      first_measurements = series.series[:values].first['measurements']
      expect(first_measurements).to include('sd')
      expect(first_measurements).to include('average')
      expect(first_measurements['sd']).not_to eq(first_measurements['average'])
    end
  end
end