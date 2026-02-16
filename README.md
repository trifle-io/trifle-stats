# Trifle::Stats

[![Gem Version](https://badge.fury.io/rb/trifle-stats.svg)](https://rubygems.org/gems/trifle-stats)
[![Ruby](https://github.com/trifle-io/trifle-stats/workflows/Ruby/badge.svg?branch=main)](https://github.com/trifle-io/trifle-stats)

Time-series metrics for Ruby. Track anything — signups, revenue, job durations — using the database you already have. No InfluxDB. No TimescaleDB. Just one call and your existing Postgres, Redis, MongoDB, MySQL, or SQLite.

Part of the [Trifle](https://trifle.io) ecosystem. Also available in [Elixir](https://github.com/trifle-io/trifle_stats) and [Go](https://github.com/trifle-io/trifle_stats_go).

## Why Trifle::Stats?

- **No new infrastructure** — Uses your existing database. No dedicated time-series DB to deploy, maintain, or pay for.
- **One call, many dimensions** — Track nested breakdowns (revenue by country by channel) in a single `track` call. Automatic rollup across configurable time granularities.
- **Library-first** — Start with the gem. Add [Trifle App](https://trifle.io/product-app) dashboards, [Trifle CLI](https://github.com/trifle-io/trifle-cli) terminal access, or AI agent integration via MCP when you need them.

## Quick Start

### 1. Install

```ruby
gem 'trifle-stats'
```

### 2. Configure

```ruby
Trifle::Stats.configure do |config|
  config.driver = Trifle::Stats::Driver::Postgres.new(ActiveRecord::Base.connection)
  config.granularities = ['1h', '1d', '1w', '1mo']
end
```

### 3. Track

```ruby
Trifle::Stats.track(
  key: 'orders',
  at: Time.now,
  values: {
    count: 1,
    revenue: 49_90,
    revenue_by_country: { us: 49_90 },
    revenue_by_channel: { organic: 49_90 }
  }
)
```

### 4. Query

```ruby
Trifle::Stats.values(
  key: 'orders',
  from: 1.week.ago,
  to: Time.now,
  granularity: :day
)
#=> { at: [Mon, Tue, Wed, ...], values: [{ "count" => 12, "revenue" => 598_80, ... }, ...] }
```

## Drivers

| Driver | Backend | Best for |
|--------|---------|----------|
| **Postgres** | JSONB upsert | Most production apps |
| **Redis** | Hash increment | High-throughput counters |
| **MongoDB** | Document upsert | Document-oriented stacks |
| **MySQL** | JSON column | MySQL shops |
| **SQLite** | JSON1 extension | Single-server apps, dev/test |
| **Process** | In-memory | Testing |
| **Dummy** | No-op | Disabled analytics |

## Features

- **Multiple time granularities** — minute, hour, day, week, month, quarter, year
- **Nested value hierarchies** — Track dimensional breakdowns in a single call
- **Series operations** — Aggregators (sum, avg, min, max), transponders, formatters
- **Buffered writes** — Queue metrics in-memory before flushing to reduce write load
- **Driver flexibility** — Switch backends without changing application code

## Buffered Persistence

Every `track`/`assert`/`assort` call is buffered by default. The buffer flushes on an interval, when the queue reaches a configurable size, and on shutdown (`SIGTERM`/`at_exit`).

```ruby
Trifle::Stats.configure do |config|
  config.driver = Trifle::Stats::Driver::Redis.new(Redis.new)
  config.buffer_duration = 5   # flush every ~5 seconds
  config.buffer_size = 100     # ...or sooner when 100 actions are enqueued
  config.buffer_aggregate = true
end
```

Set `buffer_enabled = false` for synchronous write-through.

## Documentation

Full guides, API reference, and examples at **[trifle.io/trifle-stats-rb](https://trifle.io/trifle-stats-rb)**

## Trifle Ecosystem

Trifle::Stats is the tracking layer. The ecosystem grows with you:

| Component | What it does |
|-----------|-------------|
| **[Trifle App](https://trifle.io/product-app)** | Dashboards, alerts, scheduled reports, AI-powered chat. Cloud or self-hosted. |
| **[Trifle CLI](https://github.com/trifle-io/trifle-cli)** | Query and push metrics from the terminal. MCP server mode for AI agents. |
| **[Trifle::Stats (Elixir)](https://github.com/trifle-io/trifle_stats)** | Elixir implementation with the same API and storage format. |
| **[Trifle Stats (Go)](https://github.com/trifle-io/trifle_stats_go)** | Go implementation with the same API and storage format. |
| **[Trifle::Traces](https://github.com/trifle-io/trifle-traces)** | Structured execution tracing for background jobs. |
| **[Trifle::Logs](https://github.com/trifle-io/trifle-logs)** | File-based log storage with ripgrep-powered search. |
| **[Trifle::Docs](https://github.com/trifle-io/trifle-docs)** | Map a folder of Markdown files to documentation URLs. |

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/trifle-io/trifle-stats.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
