require 'sneakers'

Sneakers.configure(
  connection: Bunny.new(RabbitConnectionManager.connection_settings),
  daemonize: false,
  start_worker_delay: 1,
  durable: true,
  ack: true,
  workers: Settings.sneakers.workers,
  threads: Settings.sneakers.threads,
  exchange: Settings.rabbitmq.exchange,
  exchange_type: Settings.rabbitmq.exchange_type,
  retry_timeout: 30,
  retry_max_times: 3,
  timeout_job_after: 60 * 5, # 5 minutes
  prefetch: 1,
  log: Rails.logger,
  hooks: {
    before_fork: lambda {
      Rails.logger.info('Worker: Disconnect from the database')
      ActiveRecord::Base.connection_pool.disconnect!
    },
    after_fork: lambda {
      Rails.logger.reopen
      Rails.logger.info('Worker: Reconnect to the database')
      config = Rails.application.config.database_configuration[Rails.env]
      config['reaping_frequency'] ||= (ENV['DB_REAP_FREQ'].presence || 10)
      config['pool'] ||= ENV['DB_POOL'].presence
      ActiveRecord::Base.establish_connection(config)
    }
  }
)

Sneakers.logger.level = Rails.logger.level
