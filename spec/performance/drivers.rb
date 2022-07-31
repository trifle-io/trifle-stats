require 'redis'
require 'mongo'
require 'pg'
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
      client[:trifle_stats].create
      client[:trifle_stats].indexes.create_one({key: 1}, unique: true)

      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Mongo.new(client)
      end
    end

    def postgres_config
      client = PG.connect('postgresql://postgres:password@postgres:5432')
      client.exec('DROP DATABASE STATS;') rescue ''
      client.exec('CREATE DATABASE STATS;')
      client = PG.connect('postgresql://postgres:password@postgres:5432/stats')
      client.exec("CREATE TABLE trifle_stats (key VARCHAR(255) PRIMARY KEY, data JSONB NOT NULL DEFAULT '{}'::jsonb)")

      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Postgres.new(client)
      end
    end

    def process_config
      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Process.new
      end
    end

    def configurations
      [redis_config, postgres_config, mongo_config, process_config]
    end
  end
end
