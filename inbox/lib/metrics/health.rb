require_relative 'process_info'

module Metrics
  # Показатели работоспособности процесса в формате Prometheus. Сам факт
  # ответа на запрос Prometheus превращает в метрику up, поэтому здесь
  # публикуется то, чего снаружи не видно: доступность зависимостей сервиса
  class Health
    POSTGRESQL = 'postgresql'.freeze
    RABBITMQ = 'rabbitmq'.freeze

    # Соединение для проверки живёт отдельно от рабочего: автовосстановление
    # выключено, иначе Bunny прятал бы обрыв связи, который и нужно увидеть
    CONNECTION_OPTIONS = {
      automatically_recover: false,
      connection_timeout: 3
    }.freeze

    class << self
      # Результат кешируется: Prometheus опрашивает сервис чаще, чем имеет
      # смысл дёргать базу и брокер
      def render
        @render = nil if expired?
        @render ||= begin
          @rendered_at = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
          new.render
        end
      end

      def rabbitmq_connection
        @rabbitmq_connection = nil unless @rabbitmq_connection&.open?
        @rabbitmq_connection ||= Bunny.new(
          Settings.rabbitmq.to_hash.merge(CONNECTION_OPTIONS)
        ).tap(&:start)
      end

      private

      def expired?
        return true if @rendered_at.nil?

        ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - @rendered_at >
          Settings.metrics.check_lifetime.to_f
      end
    end

    def render
      dependencies = check_dependencies

      [
        gauge(
          'service_up',
          'Работоспособность процесса микросервиса: 1 — все зависимости доступны',
          [[{}, all_available?(dependencies)]]
        ),
        gauge(
          'service_dependency_up',
          'Доступность зависимости микросервиса: 1 — отвечает',
          dependencies.map { |name, available| [{dependency: name}, bool(available)] }
        ),
        gauge(
          'service_start_time_seconds',
          'Unix-время запуска процесса микросервиса',
          [[{}, ProcessInfo.started_at]]
        )
      ].join
    end

    private

    def check_dependencies
      dependencies = {}
      dependencies[POSTGRESQL] = database_available? if database?
      dependencies[RABBITMQ] = rabbitmq_available?
      dependencies
    end

    # У распознавателей своей базы нет: active_record отключён в application.rb
    def database?
      defined?(ActiveRecord::Base)
    end

    # Живость соединения проверяется средствами адаптера, а не запросом
    # `SELECT 1`: тот шёл бы через журнал запросов и каждые несколько секунд
    # засорял бы development.log. Без verify! проверка бессмысленна:
    # соединение устанавливается лениво, и до первого запроса active?
    # отвечает false даже при работающей базе
    def database_available?
      Rails.application.executor.wrap do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          connection.verify!
          connection.active?
        end
      end
    rescue => e
      log_failure(POSTGRESQL, e)
      false
    end

    def rabbitmq_available?
      self.class.rabbitmq_connection.open?
    rescue => e
      log_failure(RABBITMQ, e)
      false
    end

    def log_failure(dependency, err)
      Rails.logger.warn("Метрики: зависимость #{dependency} недоступна — #{err.message}")
    end

    def all_available?(dependencies)
      bool(dependencies.values.all?)
    end

    def bool(value)
      value ? 1 : 0
    end

    def gauge(name, help, samples)
      lines = ["# HELP #{name} #{help}", "# TYPE #{name} gauge"]
      samples.each { |labels, value| lines << "#{name}#{format_labels(labels)} #{value}" }
      lines.join("\n") + "\n"
    end

    def format_labels(labels)
      pairs = base_labels.merge(labels).map { |name, value| "#{name}=\"#{escape(value)}\"" }
      "{#{pairs.join(',')}}"
    end

    def base_labels
      {service: ProcessInfo.service, process: ProcessInfo.kind}
    end

    def escape(value)
      value.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\"').gsub("\n", '\n')
    end
  end
end
