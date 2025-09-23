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
    context 'with explicit key' do
      it 'aggregates only the requested category' do
        result = series.format.category(path: 'categories.mobile')

        expect(result).to eq('categories.mobile' => 450.0)
      end

      it 'coerces values to floats and includes zero for missing data' do
        result = series.format.category(path: 'errors.timeout')

        expect(result).to eq('errors.timeout' => 8.0)
      end
    end

    context 'with implicit map path' do
      it 'auto-expands map targets without explicit wildcard' do
        result = series.format.category(path: 'categories')

        expect(result).to eq(
          'categories.mobile' => 450.0,
          'categories.desktop' => 760.0,
          'categories.tablet' => 190.0
        )
      end
    end

    context 'with wildcards' do
      it 'aggregates all nested keys' do
        result = series.format.category(path: 'errors.*')

        expect(result).to eq(
          'errors.network' => 8.0,
          'errors.server' => 4.0,
          'errors.timeout' => 8.0
        )
      end

      it 'handles sparse data gracefully' do
        sparse_series = Trifle::Stats::Series.new(
          at: [
            Time.parse('2023-01-01 10:00:00'),
            Time.parse('2023-01-01 11:00:00'),
            Time.parse('2023-01-01 12:00:00')
          ],
          values: [
            { 'categories' => { 'mobile' => 100, 'desktop' => 200 } },
            { 'other' => 999 },
            { 'categories' => { 'mobile' => 80, 'tablet' => 30 } }
          ]
        )

        result = sparse_series.format.category(path: 'categories.*')

        expect(result).to eq(
          'categories.desktop' => 200.0,
          'categories.mobile' => 180.0,
          'categories.tablet' => 30.0
        )
      end
    end

    context 'with slicing' do
      it 'returns one map per slice' do
        result = series.format.category(path: 'categories.*', slices: 2)

        expect(result).to eq([
          {
            'categories.desktop' => 380.0,
            'categories.mobile' => 250.0,
            'categories.tablet' => 120.0
          },
          {
            'categories.desktop' => 380.0,
            'categories.mobile' => 200.0,
            'categories.tablet' => 70.0
          }
        ])
      end

      it 'supports transforms while slicing' do
        result = series.format.category(path: 'errors.*', slices: 2) do |full_key, value|
          [[full_key, 'slice'].join(':'), value.to_i + 1]
        end

        expect(result).to eq([
          {
            'errors.network:slice' => 5.0,
            'errors.server:slice' => 3.0,
            'errors.timeout:slice' => 9.0
          },
          {
            'errors.network:slice' => 7.0,
            'errors.server:slice' => 5.0,
            'errors.timeout:slice' => 3.0
          }
        ])
      end
    end

    context 'with block transformations' do
      it 'lets the block rename keys or adjust values' do
        result = series.format.category(path: 'categories') do |full_key, value|
          [full_key.upcase, value * 2]
        end

        expect(result).to eq(
          'CATEGORIES.DESKTOP' => 1520.0,
          'CATEGORIES.MOBILE' => 900.0,
          'CATEGORIES.TABLET' => 380.0
        )
      end

      it 'falls back to original key when block returns scalar' do
        result = series.format.category(path: 'categories') do |_full_key, value|
          value / 10
        end

        expect(result).to eq(
          'categories.desktop' => 76.0,
          'categories.mobile' => 45.0,
          'categories.tablet' => 19.0
        )
      end
    end

    context 'with empty inputs' do
      it 'returns empty hash for empty series' do
        empty_series = Trifle::Stats::Series.new(at: [], values: [])
        expect(empty_series.format.category(path: 'categories.*')).to eq({})
      end

      it 'returns zero totals for completely missing path' do
        result = series.format.category(path: 'missing')

        expect(result).to eq('missing' => 0.0)
      end
    end
  end

  describe 'Series integration' do
    it 'registers category formatter on Series' do
      expect(series.format).to respond_to(:category)
    end

    it 'produces plain hashes that callers can merge' do
      result = series.format.category(path: 'categories')
      expect(result).to be_a(Hash)
      expect(result.values.all? { |value| value.is_a?(Float) }).to be(true)
    end
  end
end
