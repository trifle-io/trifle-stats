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
  let(:table_name) { 'test_stats_mysql_joined' }
  let(:driver) { described_class.new(mysql_client, table_name: table_name, joined_identifier: :full) }

  before(:each) do
    mysql_client.query("DROP TABLE IF EXISTS #{table_name}")
    described_class.setup!(mysql_client, table_name: table_name, joined_identifier: :full)
  end

  after(:all) do
    client = Mysql2::Client.new(
      host: ENV.fetch('MYSQL_HOST', 'mysql'),
      port: ENV.fetch('MYSQL_PORT', 3306).to_i,
      username: ENV.fetch('MYSQL_USER', 'root'),
      password: ENV.fetch('MYSQL_PASSWORD', 'password'),
      database: ENV.fetch('MYSQL_DATABASE', 'trifle_stats_test')
    )
    client.query('DROP TABLE IF EXISTS test_stats_mysql_joined')
    client.query('DROP TABLE IF EXISTS test_stats_mysql_partial')
    client.close
  end

  describe '.setup!' do
    it 'creates full mode schema' do
      table = 'test_stats_mysql_joined_schema'
      mysql_client.query("DROP TABLE IF EXISTS #{table}")

      described_class.setup!(mysql_client, table_name: table, joined_identifier: :full)

      columns = mysql_client.query(<<~SQL).map { |row| [row['COLUMN_NAME'], row['DATA_TYPE']] }
        SELECT COLUMN_NAME, DATA_TYPE
        FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = '#{table}'
        ORDER BY ORDINAL_POSITION
      SQL
      expect(columns).to eq([
        ['key', 'varchar'],
        ['data', 'json']
      ])
    ensure
      mysql_client.query("DROP TABLE IF EXISTS #{table}")
    end

    it 'creates partial mode schema' do
      table = 'test_stats_mysql_partial'
      mysql_client.query("DROP TABLE IF EXISTS #{table}")

      described_class.setup!(mysql_client, table_name: table, joined_identifier: :partial)

      columns = mysql_client.query(<<~SQL).map { |row| [row['COLUMN_NAME'], row['DATA_TYPE']] }
        SELECT COLUMN_NAME, DATA_TYPE
        FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = '#{table}'
        ORDER BY ORDINAL_POSITION
      SQL
      expect(columns).to eq([
        ['key', 'varchar'],
        ['at', 'datetime'],
        ['data', 'json']
      ])
    end
  end

  describe '#description' do
    it 'returns mode-aware description' do
      partial_driver = described_class.new(mysql_client, table_name: table_name, joined_identifier: :partial)

      expect(driver.description).to eq('Trifle::Stats::Driver::Mysql(J)')
      expect(partial_driver.description).to eq('Trifle::Stats::Driver::Mysql(P)')
    end
  end

  describe '.normalize_joined_identifier' do
    it 'normalizes valid values' do
      expect(described_class.normalize_joined_identifier(:full)).to eq(:full)
      expect(described_class.normalize_joined_identifier('full')).to eq(:full)
      expect(described_class.normalize_joined_identifier(:partial)).to eq(:partial)
      expect(described_class.normalize_joined_identifier('partial')).to eq(:partial)
      expect(described_class.normalize_joined_identifier(nil)).to eq(nil)
    end

    it 'raises for unsupported value' do
      expect do
        described_class.normalize_joined_identifier(:unknown)
      end.to raise_error(ArgumentError, /joined_identifier/)
    end
  end

  describe 'full mode operations' do
    let(:at_1) { Time.parse('2026-01-01 10:00:00 UTC') }
    let(:at_2) { Time.parse('2026-01-01 11:00:00 UTC') }
    let(:keys) do
      [
        Trifle::Stats::Nocturnal::Key.new(key: 'event::logs', granularity: '1h', at: at_1),
        Trifle::Stats::Nocturnal::Key.new(key: 'event::logs', granularity: '1h', at: at_2)
      ]
    end

    it 'increments and fetches values for all keys' do
      driver.inc(keys: keys, values: { count: 2, nested: { requests: 3 } })
      driver.inc(keys: [keys.first], values: { count: 1 })

      values = driver.get(keys: keys)
      expect(values).to eq([
        { 'count' => 3.0, 'nested' => { 'requests' => 3.0 } },
        { 'count' => 2.0, 'nested' => { 'requests' => 3.0 } }
      ])
    end

    it 'sets values without removing unspecified keys' do
      driver.set(keys: [keys.first], values: { count: 1, duration: 5 })
      driver.set(keys: [keys.first], values: { count: 10, status: 'ok' })

      values = driver.get(keys: [keys.first]).first
      expect(values).to eq({
        'count' => 10,
        'duration' => 5,
        'status' => 'ok'
      })
    end

    it 'tracks system writes using count and custom tracking key' do
      driver.inc(keys: [keys.first], values: { count: 2 }, count: 3, tracking_key: 'manual')

      system_key = Trifle::Stats::Nocturnal::Key.new(
        key: '__system__key__',
        granularity: keys.first.granularity,
        at: keys.first.at
      )
      values = driver.get(keys: [system_key]).first
      expect(values).to eq({
        'count' => 3.0,
        'keys' => { 'manual' => 3.0 }
      })
    end

    it 'disables system tracking when configured' do
      disabled = described_class.new(
        mysql_client,
        table_name: table_name,
        joined_identifier: :full,
        system_tracking: false
      )

      disabled.inc(keys: [keys.first], values: { count: 2 }, count: 4)

      system_key = Trifle::Stats::Nocturnal::Key.new(
        key: '__system__key__',
        granularity: keys.first.granularity,
        at: keys.first.at
      )
      expect(disabled.get(keys: [system_key])).to eq([{}])
    end
  end

  describe 'partial mode operations' do
    let(:partial_table) { 'test_stats_mysql_partial_mode' }
    let(:at) { Time.parse('2026-01-01 10:00:00 UTC') }
    let(:key) { Trifle::Stats::Nocturnal::Key.new(key: 'metric', granularity: '1h', at: at) }

    before do
      mysql_client.query("DROP TABLE IF EXISTS #{partial_table}")
      described_class.setup!(mysql_client, table_name: partial_table, joined_identifier: :partial)
    end

    after do
      mysql_client.query("DROP TABLE IF EXISTS #{partial_table}")
    end

    it 'stores key and at separately while joining key+granularity' do
      partial_driver = described_class.new(mysql_client, table_name: partial_table, joined_identifier: 'partial')
      partial_driver.inc(keys: [key], values: { count: 5 })

      row = mysql_client.query("SELECT `key`, CAST(`at` AS CHAR) AS at_value, CAST(`data` AS CHAR) AS data FROM `#{partial_table}` WHERE `key` = 'metric::1h' LIMIT 1").first
      expect(row['key']).to eq('metric::1h')
      expect(row['at_value']).to start_with(at.utc.strftime('%Y-%m-%d %H:%M:%S'))
      expect(JSON.parse(row['data'])).to eq('count' => 5.0)
    end
  end
end
