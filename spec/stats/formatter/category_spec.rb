require 'time'

RSpec.describe Trifle::Stats::Formatter::Category do
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
          'categories' => { 'mobile' => 100, 'desktop' => 200, 'tablet' => 50 },
          'errors' => { 'timeout' => 5, 'network' => 3 }
        },
        { 
          'categories' => { 'mobile' => 150, 'desktop' => 180, 'tablet' => 70 },
          'errors' => { 'timeout' => 2, 'server' => 1 }
        },
        { 
          'categories' => { 'mobile' => 80, 'desktop' => 220, 'tablet' => 30 },
          'errors' => { 'network' => 4, 'server' => 2 }
        },
        { 
          'categories' => { 'mobile' => 120, 'desktop' => 160, 'tablet' => 40 },
          'errors' => { 'timeout' => 1, 'network' => 1, 'server' => 1 }
        }
      ]
    }
  end
  let(:series) { Trifle::Stats::Series.new(series_data) }

  describe '#format' do
    context 'with simple path' do
      it 'aggregates categories across all time points' do
        result = series.format.category(path: 'categories')

        expect(result).to eq([{
          'mobile' => 450.0,   # 100 + 150 + 80 + 120
          'desktop' => 760.0,  # 200 + 180 + 220 + 160
          'tablet' => 190.0    # 50 + 70 + 30 + 40
        }])
      end

      it 'handles different category structures' do
        result = series.format.category(path: 'errors')

        expect(result).to eq([{
          'timeout' => 8.0,  # 5 + 2 + 0 + 1
          'network' => 8.0,  # 3 + 0 + 4 + 1
          'server' => 4.0    # 0 + 1 + 2 + 1
        }])
      end
    end

    context 'with nested path' do
      let(:nested_series_data) do
        {
          at: [
            Time.parse('2023-01-01 10:00:00'),
            Time.parse('2023-01-01 11:00:00')
          ],
          values: [
            { 'stats' => { 'browsers' => { 'chrome' => 100, 'firefox' => 50 } } },
            { 'stats' => { 'browsers' => { 'chrome' => 120, 'safari' => 30 } } }
          ]
        }
      end
      let(:nested_series) { Trifle::Stats::Series.new(nested_series_data) }

      it 'handles nested paths with dot notation' do
        result = nested_series.format.category(path: 'stats.browsers')

        expect(result).to eq([{
          'chrome' => 220.0,   # 100 + 120
          'firefox' => 50.0,   # 50 + 0
          'safari' => 30.0     # 0 + 30
        }])
      end
    end

    context 'with slicing' do
      it 'creates separate category aggregations for each slice' do
        result = series.format.category(path: 'categories', slices: 2)

        expect(result).to eq([
          {
            'mobile' => 250.0,   # 100 + 150
            'desktop' => 380.0,  # 200 + 180
            'tablet' => 120.0    # 50 + 70
          },
          {
            'mobile' => 200.0,   # 80 + 120
            'desktop' => 380.0,  # 220 + 160
            'tablet' => 70.0     # 30 + 40
          }
        ])
      end

      it 'handles slicing with 4 slices (each time point separate)' do
        result = series.format.category(path: 'categories', slices: 4)

        expect(result).to eq([
          { 'mobile' => 100.0, 'desktop' => 200.0, 'tablet' => 50.0 },
          { 'mobile' => 150.0, 'desktop' => 180.0, 'tablet' => 70.0 },
          { 'mobile' => 80.0, 'desktop' => 220.0, 'tablet' => 30.0 },
          { 'mobile' => 120.0, 'desktop' => 160.0, 'tablet' => 40.0 }
        ])
      end

      it 'handles slicing with varying category keys' do
        result = series.format.category(path: 'errors', slices: 2)

        expect(result).to eq([
          {
            'timeout' => 7.0,  # 5 + 2
            'network' => 3.0,  # 3 + 0
            'server' => 1.0    # 0 + 1
          },
          {
            'timeout' => 1.0,  # 0 + 1
            'network' => 5.0,  # 4 + 1
            'server' => 3.0    # 2 + 1
          }
        ])
      end
    end

    context 'with missing values' do
      let(:sparse_series_data) do
        {
          at: [
            Time.parse('2023-01-01 10:00:00'),
            Time.parse('2023-01-01 11:00:00'),
            Time.parse('2023-01-01 12:00:00')
          ],
          values: [
            { 'categories' => { 'mobile' => 100, 'desktop' => 200 } },
            { 'other' => 999 }, # No categories key - using numeric value
            { 'categories' => { 'mobile' => 80, 'tablet' => 30 } }
          ]
        }
      end
      let(:sparse_series) { Trifle::Stats::Series.new(sparse_series_data) }

      it 'handles missing category data gracefully' do
        result = sparse_series.format.category(path: 'categories')

        expect(result).to eq([{
          'mobile' => 180.0,   # 100 + 0 + 80
          'desktop' => 200.0,  # 200 + 0 + 0
          'tablet' => 30.0     # 0 + 0 + 30
        }])
      end
    end

    context 'with empty series' do
      let(:empty_series_data) { { at: [], values: [] } }
      let(:empty_series) { Trifle::Stats::Series.new(empty_series_data) }

      it 'returns empty array for empty series' do
        result = empty_series.format.category(path: 'categories')

        expect(result).to eq([])
      end
    end

    context 'with non-existent path' do
      it 'returns empty hash for completely missing path' do
        result = series.format.category(path: 'nonexistent')

        expect(result).to eq([{}])
      end

      it 'returns empty hash for missing nested path' do
        result = series.format.category(path: 'stats.missing')

        expect(result).to eq([{}])
      end
    end

    context 'with block transformation' do
      it 'applies block transformation to each category' do
        result = series.format.category(path: 'categories') do |key, value|
          [key.upcase, value * 2]
        end

        expect(result).to eq([{
          'MOBILE' => 900.0,   # (100 + 150 + 80 + 120) * 2
          'DESKTOP' => 1520.0, # (200 + 180 + 220 + 160) * 2
          'TABLET' => 380.0    # (50 + 70 + 30 + 40) * 2
        }])
      end

      it 'applies block transformation with slicing' do
        result = series.format.category(path: 'categories', slices: 2) do |key, value|
          ["#{key}_device", value / 10]
        end

        expect(result).to eq([
          {
            'mobile_device' => 25.0,   # (100 + 150) / 10
            'desktop_device' => 38.0,  # (200 + 180) / 10
            'tablet_device' => 12.0    # (50 + 70) / 10
          },
          {
            'mobile_device' => 20.0,   # (80 + 120) / 10
            'desktop_device' => 38.0,  # (220 + 160) / 10
            'tablet_device' => 7.0     # (30 + 40) / 10
          }
        ])
      end

      it 'handles conditional transformations in block' do
        result = series.format.category(path: 'categories') do |key, value|
          if key == 'mobile'
            ['mobile_total', value]
          else
            ['other_devices', value]
          end
        end

        expect(result).to eq([{
          'mobile_total' => 450.0,  # 100 + 150 + 80 + 120
          'other_devices' => 950.0  # (200 + 180 + 220 + 160) + (50 + 70 + 30 + 40)
        }])
      end
    end

    context 'with zero and negative values' do
      let(:special_series_data) do
        {
          at: [
            Time.parse('2023-01-01 10:00:00'),
            Time.parse('2023-01-01 11:00:00')
          ],
          values: [
            { 'metrics' => { 'positive' => 100, 'zero' => 0, 'negative' => -50 } },
            { 'metrics' => { 'positive' => 200, 'zero' => 0, 'negative' => -30 } }
          ]
        }
      end
      let(:special_series) { Trifle::Stats::Series.new(special_series_data) }

      it 'correctly handles zero and negative values' do
        result = special_series.format.category(path: 'metrics')

        expect(result).to eq([{
          'positive' => 300.0,  # 100 + 200
          'zero' => 0.0,        # 0 + 0
          'negative' => -80.0   # -50 + -30
        }])
      end
    end

    context 'with complex slicing scenarios' do
      let(:larger_series_data) do
        {
          at: (1..6).map { |i| Time.parse("2023-01-01 #{9+i}:00:00") },
          values: (1..6).map do |i|
            { 'devices' => { 'mobile' => i * 10, 'desktop' => i * 20 } }
          end
        }
      end
      let(:larger_series) { Trifle::Stats::Series.new(larger_series_data) }

      it 'handles slicing with 3 slices' do
        result = larger_series.format.category(path: 'devices', slices: 3)

        expect(result).to eq([
          {
            'mobile' => 30.0,   # 10 + 20
            'desktop' => 60.0   # 20 + 40
          },
          {
            'mobile' => 70.0,   # 30 + 40
            'desktop' => 140.0  # 60 + 80
          },
          {
            'mobile' => 110.0,  # 50 + 60
            'desktop' => 220.0  # 100 + 120
          }
        ])
      end

      it 'handles uneven slicing' do
        result = larger_series.format.category(path: 'devices', slices: 4)

        # With 6 values and 4 slices: takes last 4 values, 1 value per slice
        expect(result).to eq([
          { 'mobile' => 30.0, 'desktop' => 60.0 },   # values[2]
          { 'mobile' => 40.0, 'desktop' => 80.0 },   # values[3]
          { 'mobile' => 50.0, 'desktop' => 100.0 },  # values[4]
          { 'mobile' => 60.0, 'desktop' => 120.0 }   # values[5]
        ])
      end
    end
  end

  describe 'integration with Series' do
    it 'is properly registered as category formatter' do
      expect(series.format).to respond_to(:category)
    end

    it 'can be chained with other operations' do
      categories = series.format.category(path: 'categories')
      expect(categories).to be_an(Array)
      expect(categories.first).to be_a(Hash)
      expect(categories.first.values).to all(be_a(Float))
    end

    it 'provides different structure than timeline formatter' do
      # Use a simple numeric path that timeline can handle
      timeline = series.format.timeline(path: 'errors.timeout')
      category = series.format.category(path: 'categories')

      # Timeline returns array of [time, value] pairs for scalar values
      # Category returns hash of aggregated category totals
      expect(timeline.first.first).to be_an(Array)  # Timeline structure: [[time, value], ...]
      expect(category.first).to be_a(Hash)          # Category structure: {category => total}

      expect(timeline).not_to eq(category)
    end

    it 'handles large category sets efficiently' do
      large_categories = {}
      (1..100).each { |i| large_categories["category_#{i}"] = i }
      
      large_series_data = {
        at: [Time.parse('2023-01-01 10:00:00')],
        values: [{ 'categories' => large_categories }]
      }
      large_series = Trifle::Stats::Series.new(large_series_data)

      result = large_series.format.category(path: 'categories')
      
      expect(result.first.keys.length).to eq(100)
      expect(result.first['category_50']).to eq(50.0)
    end
  end
end