require 'redis'
require 'mongo'
require 'pg'
require 'sqlite3'
require 'byebug'

module Performance
  class Drivers
    def redis_config
      client = Redis.new(url: 'redis://redis:6379/0')
      client.flushall

      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Redis.new(client, system_tracking: true)
        config.buffer_enabled = false
      end
    end

    def mongo_separated_config
      client = Mongo::Client.new('mongodb://mongo:27017/stats_separated')
      client[:trifle_stats].drop
      Trifle::Stats::Driver::Mongo.setup!(client, joined_identifier: nil)

      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Mongo.new(client, joined_identifier: nil, system_tracking: true)
       config.buffer_enabled = false
      end
    end

    def mongo_joined_config
      client = Mongo::Client.new('mongodb://mongo:27017/stats_joined')
      client[:trifle_stats].drop
      Trifle::Stats::Driver::Mongo.setup!(client)

      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Mongo.new(client, expire_after: 10, system_tracking: true)
        config.buffer_enabled = false
      end
    end

    def postgres_joined_config
      client = PG.connect('postgresql://postgres:password@postgres:5432')
      client.exec('DROP DATABASE STATS_JOINED;') rescue ''
      client.exec('CREATE DATABASE STATS_JOINED;')
      client = PG.connect('postgresql://postgres:password@postgres:5432/stats_joined')
      Trifle::Stats::Driver::Postgres.setup!(client)

      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Postgres.new(client, system_tracking: true)
       config.buffer_enabled = false
      end
    end

    def postgres_separated_config
      client = PG.connect('postgresql://postgres:password@postgres:5432')
      client.exec('DROP DATABASE STATS_SEPARATED;') rescue ''
      client.exec('CREATE DATABASE STATS_SEPARATED;')
      client = PG.connect('postgresql://postgres:password@postgres:5432/stats_separated')
      Trifle::Stats::Driver::Postgres.setup!(client, joined_identifier: nil)

      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Postgres.new(client, joined_identifier: nil, system_tracking: true)
        config.buffer_enabled = false
      end
    end

    def process_config
      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Process.new
        config.buffer_enabled = false
      end
    end

    def sqlite_joined_config
      File.delete('stats_joined.db') if File.exist?('stats_joined.db')
      Trifle::Stats::Driver::Sqlite.setup!(SQLite3::Database.new('stats_joined.db'))

      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Sqlite.new(SQLite3::Database.new('stats_joined.db'), system_tracking: true)
        config.buffer_enabled = false
      end
    end

    def sqlite_separated_config
      File.delete('stats_separated.db') if File.exist?('stats_separated.db')
      Trifle::Stats::Driver::Sqlite.setup!(SQLite3::Database.new('stats_separated.db'), joined_identifier: nil)

      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Sqlite.new(SQLite3::Database.new('stats_separated.db'), joined_identifier: nil, system_tracking: true)
        config.buffer_enabled = false
      end
    end

   def configurations
      [
        redis_config,
        postgres_separated_config,
        postgres_joined_config,
        mongo_separated_config,
        mongo_joined_config,
        process_config,
        sqlite_separated_config,
        sqlite_joined_config
      ]
    end
  end
end
