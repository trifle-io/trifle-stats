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
        config.driver = Trifle::Stats::Driver::Redis.new(client)
      end
    end

    def mongo_config
      client = Mongo::Client.new('mongodb://mongo:27017/stats')
      client[:trifle_stats].drop
      Trifle::Stats::Driver::Mongo.setup!(client)

      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Mongo.new(client)
      end
    end

    def postgres_config
      client = PG.connect('postgresql://postgres:password@postgres:5432')
      client.exec('DROP DATABASE STATS;') rescue ''
      client.exec('CREATE DATABASE STATS;')
      client = PG.connect('postgresql://postgres:password@postgres:5432/stats')
      Trifle::Stats::Driver::Postgres.setup!(client)

      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Postgres.new(client)
      end
    end

    def process_config
      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Process.new
      end
    end

    def sqlite_config
      File.delete('stats.db') if File.exist?('stats.db')
      Trifle::Stats::Driver::Sqlite.setup!

      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Sqlite.new
      end
    end

    def configurations
      [redis_config, postgres_config, mongo_config, process_config, sqlite_config]
    end
  end
end
