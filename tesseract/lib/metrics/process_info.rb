module Metrics
  # Сведения о процессе, которые становятся метками метрик. У сервиса два-три
  # долгоживущих процесса на одном образе (веб-панель, потребитель Sneakers,
  # планировщик заданий), и в Prometheus их нужно различать
  class ProcessInfo
    WEB = 'web'.freeze
    SNEAKERS = 'sneakers'.freeze
    JOBS = 'jobs'.freeze

    # Задача, которой запускается потребитель сообщений
    SNEAKERS_TASK = 'sneakers:run'.freeze
    # Планировщик заданий inbox запускается из bin/jobs
    JOBS_PROGRAM = 'jobs'.freeze

    STARTED_AT = Time.now.to_i

    class << self
      # Имя сервиса берётся из модуля приложения: EventLogger -> event-logger
      def service
        @service ||= Rails.application.class.module_parent_name.underscore.dasherize
      end

      # nil означает короткоживущий процесс — консоль, rake-задачу, спеки.
      # Экспортер в них не поднимается: порт занимать незачем, а метрики
      # такого процесса всё равно никто не успеет собрать
      def kind
        @kind ||= ENV['METRICS_PROCESS'].presence || detect_kind
      end

      def started_at
        STARTED_AT
      end

      private

      # ARGV к этому моменту уже разобран запускающей командой, поэтому тип
      # процесса определяется по тому, что она успела загрузить: rake-задача
      # потребителя, имя программы планировщика, класс сервера Rails
      def detect_kind
        return SNEAKERS if rake_task?(SNEAKERS_TASK)
        return JOBS if $PROGRAM_NAME.end_with?(JOBS_PROGRAM)
        return WEB if defined?(Rails::Server)

        nil
      end

      def rake_task?(name)
        defined?(Rake) && Rake.application.top_level_tasks.include?(name)
      rescue StandardError
        false
      end
    end
  end
end
