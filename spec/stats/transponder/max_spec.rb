require 'time'

RSpec.describe Trifle::Stats::Transponder::Max do
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
          'metrics' => { 'score_a' => 8, 'score_b' => 2, 'score_c' => 7 }
        },
        { 
          'requests' => { 'items' => 20, 'books' => 8, 'shoes' => 12 },
          'metrics' => { 'score_a' => 9, 'score_b' => 4, 'score_c' => 6 }
        },
        { 
          'requests' => { 'items' => 5, 'books' => 15, 'shoes' => 10 },
          'metrics' => { 'score_a' => 7, 'score_b' => 3, 'score_c' => 8 }
        },
        { 
          'requests' => { 'items' => 25, 'books' => 10, 'shoes' => 5 },
          'metrics' => { 'score_a' => 10, 'score_b' => 5, 'score_c' => 9 }
        }
      ]
    }
  end
  let(:series) { Trifle::Stats::Series.new(series_data) }

  describe '#transpond' do
    context 'with multiple values' do
      it 'finds maximum from multiple paths' do
        series.transpond.max(paths: ['requests.items', 'requests.books', 'requests.shoes'], response: 'requests.max')

        values = series.series[:values]
        expect(values[0]['requests']['max']).to eq(15) # max(10, 5, 15)
        expect(values[1]['requests']['max']).to eq(20) # max(20, 8, 12)
        expect(values[2]['requests']['max']).to eq(15) # max(5, 15, 10)
        expect(values[3]['requests']['max']).to eq(25) # max(25, 10, 5)
      end

      it 'handles different metric paths' do
        series.transpond.max(paths: ['metrics.score_a', 'metrics.score_b'], response: 'metrics.max')

        values = series.series[:values]
        expect(values[0]['metrics']['max']).to eq(8) # max(8, 2)
        expect(values[1]['metrics']['max']).to eq(9) # max(9, 4)
        expect(values[2]['metrics']['max']).to eq(7) # max(7, 3)
        expect(values[3]['metrics']['max']).to eq(10) # max(10, 5)
      end
    end

    context 'with single value' do
      it 'works with single path in array' do
        series.transpond.max(paths: ['requests.items'], response: 'requests.items_max')

        values = series.series[:values]
        expect(values[0]['requests']['items_max']).to eq(10)
        expect(values[1]['requests']['items_max']).to eq(20)
        expect(values[2]['requests']['items_max']).to eq(5)
        expect(values[3]['requests']['items_max']).to eq(25)
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
        incomplete_series.transpond.max(paths: ['requests.items', 'requests.books'], response: 'requests.max')

        values = incomplete_series.series[:values]
        expect(values[0]['requests']).not_to have_key('max')
        expect(values[0]['requests']['items']).to eq(10)
      end
    end

  end
end