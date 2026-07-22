require 'spec_helper'

RSpec.describe Trifle::Stats::Driver::Api do
  Response = Struct.new(:code, :body, :headers) do
    def [](name)
      headers[name]
    end
  end

  class RecordingTransport
    attr_reader :calls

    def initialize(response = Response.new('201', '', {}))
      @response = response
      @calls = []
    end

    def call(**args)
      @calls << args
      @response
    end
  end

  it 'sends track and assert writes immediately as gzip JSON' do
    transport = RecordingTransport.new
    driver = described_class.new(token: 'secret', project_id: 'project-1', transport: transport)
    config = Trifle::Stats::Configuration.new
    config.driver = driver
    config.buffer_enabled = true
    at = Time.utc(2026, 7, 22, 12)

    Trifle::Stats.track(key: 'orders', at: at, values: { count: 1 }, config: config, untracked: true)
    Trifle::Stats.assert(key: 'state::orders', at: at, values: { pending: 4 }, config: config)

    expect(config.storage).to equal(driver)
    expect(transport.calls.size).to eq(2)
    requests = transport.calls.map { |call| call.fetch(:request) }
    payloads = requests.map { |request| JSON.parse(Zlib.gunzip(request.body)) }
    expect(payloads.map { |payload| payload['operation'] }).to eq(%w[track assert])
    expect(payloads.first).to include('key' => 'orders', 'values' => { 'count' => 1 }, 'untracked' => true)
    expect(payloads.first['at']).to eq('2026-07-22T12:00:00.000000Z')
    expect(requests.first['Authorization']).to eq('Bearer secret')
    expect(requests.first['X-Trifle-Source-Id']).to eq('project-1')
    expect(requests.first['Content-Encoding']).to eq('gzip')
    expect(transport.calls.first.fetch(:uri).to_s).to eq('https://app.trifle.io/api/v1/metrics')
  end

  it 'surfaces overload metadata without retrying' do
    response = Response.new('429', 'busy', { 'Retry-After' => '3' })
    transport = RecordingTransport.new(response)
    driver = described_class.new(token: 'secret', project_id: 'project-1', transport: transport)

    expect do
      driver.direct_write(operation: :track, key: 'orders', at: Time.now, values: { count: 1 })
    end.to raise_error(described_class::Error) { |error| expect(error.retry_after).to eq('3') }
    expect(transport.calls.size).to eq(1)
  end

  it 'validates credentials and rejects unsupported operations' do
    expect { described_class.new(token: '', project_id: 'project-1') }.to raise_error(ArgumentError)
    driver = described_class.new(token: 'secret', project_id: 'project-1')
    expect { driver.get(keys: []) }.to raise_error(described_class::Error)
  end

  it 'marks transport failures as unknown delivery without retrying' do
    calls = 0
    transport = Object.new
    transport.define_singleton_method(:call) do |**|
      calls += 1
      raise Timeout::Error, 'timed out'
    end
    driver = described_class.new(token: 'secret', project_id: 'project-1', transport: transport)

    expect do
      driver.direct_write(operation: :track, key: 'orders', at: Time.now, values: { count: 1 })
    end.to raise_error(described_class::Error) { |error| expect(error.delivery_unknown).to be(true) }
    expect(calls).to eq(1)
  end
end
