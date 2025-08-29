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
          'requests' => { 'items' => 10, 'books' => 5, 'shoes' => 15 },
          'metrics' => { 'score_a' => 8, 'score_b' => 2, 'score_c' => 6 }
        },
        { 
          'requests' => { 'items' => 20, 'books' => 8, 'shoes' => 12 },
          'metrics' => { 'score_a' => 9, 'score_b' => 4, 'score_c' => 7 }
        },
        { 
          'requests' => { 'items' => 6, 'books' => 15, 'shoes' => 9 },
          'metrics' => { 'score_a' => 7, 'score_b' => 3, 'score_c' => 8 }
        },
        { 
          'requests' => { 'items' => 24, 'books' => 10, 'shoes' => 6 },
          'metrics' => { 'score_a' => 12, 'score_b' => 6, 'score_c' => 9 }
        }
      ]
    }
  end
  let(:series) { Trifle::Stats::Series.new(series_data) }

  describe '#transpond' do
    context 'with multiple values' do
      it 'calculates mean from multiple paths' do
        series.transpond.mean(paths: ['requests.items', 'requests.books', 'requests.shoes'], response: 'requests.mean')

        values = series.series[:values]
        expect(values[0]['requests']['mean']).to eq(10.0) # (10 + 5 + 15) / 3
        expect(values[1]['requests']['mean']).to be_within(0.01).of(13.33) # (20 + 8 + 12) / 3
        expect(values[2]['requests']['mean']).to eq(10.0) # (6 + 15 + 9) / 3
        expect(values[3]['requests']['mean']).to be_within(0.01).of(13.33) # (24 + 10 + 6) / 3
      end

      it 'handles different metric paths' do
        series.transpond.mean(paths: ['metrics.score_a', 'metrics.score_b'], response: 'metrics.mean')

        values = series.series[:values]
        expect(values[0]['metrics']['mean']).to eq(5.0) # (8 + 2) / 2
        expect(values[1]['metrics']['mean']).to eq(6.5) # (9 + 4) / 2
        expect(values[2]['metrics']['mean']).to eq(5.0) # (7 + 3) / 2
        expect(values[3]['metrics']['mean']).to eq(9.0) # (12 + 6) / 2
      end
    end

    context 'with single value' do
      it 'works with single path in array' do
        series.transpond.mean(paths: ['requests.items'], response: 'requests.items_mean')

        values = series.series[:values]
        expect(values[0]['requests']['items_mean']).to eq(10.0)
        expect(values[1]['requests']['items_mean']).to eq(20.0)
        expect(values[2]['requests']['items_mean']).to eq(6.0)
        expect(values[3]['requests']['items_mean']).to eq(24.0)
      end
    end

    context 'with missing data' do
      let(:incomplete_series_data) do
        {
          at: [Time.parse('2023-01-01 10:00:00')],
          values: [
            { 'requests' => { 'items' => 10 } } # Missing 'books' path
          ]
        }
      end
      let(:incomplete_series) { Trifle::Stats::Series.new(incomplete_series_data) }

      it 'skips calculation when any path is missing' do
        incomplete_series.transpond.mean(paths: ['requests.items', 'requests.books'], response: 'requests.mean')

        values = incomplete_series.series[:values]
        expect(values[0]['requests']).not_to have_key('mean')
        expect(values[0]['requests']['items']).to eq(10)
      end
    end

  end
end