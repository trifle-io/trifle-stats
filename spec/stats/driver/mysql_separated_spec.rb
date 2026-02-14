require 'mysql2'
require 'time'

RSpec.describe Trifle::Stats::Driver::Mysql do
  let(:mysql_config) do
    {
      host: ENV.fetch('MYSQL_HOST', 'mysql'),
      port: ENV.fetch('MYSQL_PORT', 3306).to_i,
      username: ENV.fetch('MYSQL_USER', 'root'),
      password: ENV.fetch('MYSQL_PASSWORD', 'password'),
      database: ENV.fetch('MYSQL_DATABASE', 'trifle_stats_test')
    }
  end
  let(:mysql_client) { Mysql2::Client.new(mysql_config.merge(cast_booleans: true)) }
  let(:table_name) { 'test_stats_mysql_separated' }
  let(:ping_table_name) { 'test_stats_mysql_separated_ping' }
  let(:driver) do
    described_class.new(
      mysql_client,
      table_name: table_name,
      ping_table_name: ping_table_name,
      joined_identifier: nil
    )
  end

  before(:each) do
    mysql_client.query("DROP TABLE IF EXISTS #{table_name}")
    mysql_client.query("DROP TABLE IF EXISTS #{ping_table_name}")
    described_class.setup!(
      mysql_client,
      table_name: table_name,
      ping_table_name: ping_table_name,
      joined_identifier: nil
    )
  end

  after(:all) do
    client = Mysql2::Client.new(
      host: ENV.fetch('MYSQL_HOST', 'mysql'),
      port: ENV.fetch('MYSQL_PORT', 3306).to_i,
      username: ENV.fetch('MYSQL_USER', 'root'),
      password: ENV.fetch('MYSQL_PASSWORD', 'password'),
      database: ENV.fetch('MYSQL_DATABASE', 'trifle_stats_test')
    )
    client.query('DROP TABLE IF EXISTS test_stats_mysql_separated')
    client.query('DROP TABLE IF EXISTS test_stats_mysql_separated_ping')
    client.close
  end

  describe '.setup!' do
    it 'creates separated mode main and ping tables' do
      main_columns = mysql_client.query(<<~SQL).map { |row| [row['COLUMN_NAME'], row['DATA_TYPE']] }
        SELECT COLUMN_NAME, DATA_TYPE
        FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = '#{table_name}'
        ORDER BY ORDINAL_POSITION
      SQL

      ping_columns = mysql_client.query(<<~SQL).map { |row| [row['COLUMN_NAME'], row['DATA_TYPE']] }
        SELECT COLUMN_NAME, DATA_TYPE
        FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = '#{ping_table_name}'
        ORDER BY ORDINAL_POSITION
      SQL

      expect(main_columns).to eq([
        ['key', 'varchar'],
        ['granularity', 'varchar'],
        ['at', 'datetime'],
        ['data', 'json']
      ])
      expect(ping_columns).to eq([
        ['key', 'varchar'],
        ['at', 'datetime'],
        ['data', 'json']
      ])
    end
  end

  describe '#description' do
    it 'returns separated description' do
      expect(driver.description).to eq('Trifle::Stats::Driver::Mysql(S)')
    end
  end

  describe 'separated mode operations' do
    let(:at_1) { Time.parse('2026-01-01 10:00:00 UTC') }
    let(:at_2) { Time.parse('2026-01-01 11:00:00 UTC') }
    let(:keys) do
      [
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '1h', at: at_1),
        Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '1h', at: at_2)
      ]
    end

    it 'increments and retrieves values by separated identifier' do
      driver.inc(keys: keys, values: { count: 1 })
      driver.inc(keys: [keys.first], values: { count: 4, nested: { requests: 2 } })

      values = driver.get(keys: keys)
      expect(values).to eq([
        { 'count' => 5.0, 'nested' => { 'requests' => 2.0 } },
        { 'count' => 1.0 }
      ])
    end

    it 'tracks system data in separated mode' do
      driver.set(keys: [keys.first], values: { state: 'ok' }, count: 2, tracking_key: 'custom')

      system_key = Trifle::Stats::Nocturnal::Key.new(
        key: '__system__key__',
        granularity: keys.first.granularity,
        at: keys.first.at
      )
      values = driver.get(keys: [system_key]).first
      expect(values).to eq({
        'count' => 2.0,
        'keys' => { 'custom' => 2.0 }
      })
    end
  end

  describe '#ping and #scan' do
    let(:key_1) { Trifle::Stats::Nocturnal::Key.new(key: 'status', granularity: '1h', at: Time.parse('2026-01-01 10:00:00 UTC')) }
    let(:key_2) { Trifle::Stats::Nocturnal::Key.new(key: 'status', granularity: '1h', at: Time.parse('2026-01-01 12:00:00 UTC')) }

    it 'stores latest ping and retrieves it via scan' do
      driver.ping(key: key_1, values: { state: 'running', count: 1 })
      driver.ping(key: key_2, values: { state: 'idle', count: 2 })

      scan = driver.scan(key: Trifle::Stats::Nocturnal::Key.new(key: 'status'))
      expect(scan[0]).to be_a(Time)
      expect(scan[1]['data']).to eq({ 'state' => 'idle', 'count' => 2 })
    end

    it 'returns empty array when ping key does not exist' do
      expect(driver.scan(key: Trifle::Stats::Nocturnal::Key.new(key: 'missing'))).to eq([])
    end

    it 'returns empty array for joined mode ping/scan' do
      joined_driver = described_class.new(mysql_client, table_name: table_name, joined_identifier: :full)
      expect(joined_driver.ping(key: key_1, values: { state: 'running' })).to eq([])
      expect(joined_driver.scan(key: Trifle::Stats::Nocturnal::Key.new(key: 'status'))).to eq([])
    end
  end
end
