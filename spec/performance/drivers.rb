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
        config.designator = Trifle::Stats::Designator::Linear.new(min: 0, max: 100, step: 10)
      end
    end

    def mongo_separated_config
      client = Mongo::Client.new('mongodb://mongo:27017/stats_separated')
      client[:trifle_stats].drop
      Trifle::Stats::Driver::Mongo.setup!(client, joined_identifier: false)

      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Mongo.new(client, joined_identifier: false)
        config.designator = Trifle::Stats::Designator::Linear.new(min: 0, max: 100, step: 10)
      end
    end

    def mongo_joined_config
      client = Mongo::Client.new('mongodb://mongo:27017/stats_joined')
      client[:trifle_stats].drop
      Trifle::Stats::Driver::Mongo.setup!(client)

      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Mongo.new(client)
        config.designator = Trifle::Stats::Designator::Linear.new(min: 0, max: 100, step: 10)
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
        config.designator = Trifle::Stats::Designator::Linear.new(min: 0, max: 100, step: 10)
      end
    end

    def process_config
      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Process.new
        config.designator = Trifle::Stats::Designator::Linear.new(min: 0, max: 100, step: 10)
      end
    end

    def sqlite_config
      File.delete('stats.db') if File.exist?('stats.db')
      Trifle::Stats::Driver::Sqlite.setup!

      Trifle::Stats::Configuration.new.tap do |config|
        config.driver = Trifle::Stats::Driver::Sqlite.new
        config.designator = Trifle::Stats::Designator::Linear.new(min: 0, max: 100, step: 10)
      end
    end

    def configurations
      [redis_config, postgres_config, mongo_separated_config, mongo_joined_config, process_config, sqlite_config]
    end
  end
end
