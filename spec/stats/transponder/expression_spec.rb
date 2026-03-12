# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Trifle::Stats::Transponder::Expression do
  let(:series) do
    Trifle::Stats::Series.new(
      at: [Time.parse('2023-01-01 10:00:00'), Time.parse('2023-01-01 11:00:00')],
      values: [
        { metrics: { sum: 30, count: 3 } },
        { metrics: { sum: 20, count: 4 } }
      ]
    )
  end

  it 'registers expression on the series transponder proxy' do
    expect(series.transpond).to respond_to(:expression)
  end

  it 'applies arithmetic expressions' do
    series.transpond.expression(
      paths: ['metrics.sum', 'metrics.count'],
      expression: 'a / b',
      response: 'metrics.average'
    )

    values = series.series[:values]
    expect(values[0].dig('metrics', 'average')).to eq(BigDecimal('10'))
    expect(values[1].dig('metrics', 'average')).to eq(BigDecimal('5'))
  end

  it 'creates nested response paths when missing' do
    series.transpond.expression(
      paths: ['metrics.sum', 'metrics.count'],
      expression: 'a / b',
      response: 'metrics.duration.average'
    )

    expect(series.series[:values][0].dig('metrics', 'duration', 'average')).to eq(BigDecimal('10'))
  end

  it 'returns nil when an input path is missing' do
    series.transpond.expression(
      paths: ['metrics.sum', 'metrics.missing'],
      expression: 'a / b',
      response: 'metrics.average'
    )

    expect(series.series[:values][0].dig('metrics', 'average')).to be_nil
  end

  it 'rejects wildcard paths during stage 1' do
    expression = described_class.new

    expect do
      expression.validate(paths: ['codes.*.count'], expression: 'a', response: 'codes.*.average')
    end.to raise_error(ArgumentError, 'Wildcard paths are not supported yet.')
  end
end
