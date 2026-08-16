require 'socket'
require_relative 'health'
require_relative 'process_info'

module Metrics
  # HTTP-сервер метрик: слушает отдельный порт в фоновом потоке.
  #
  # Собственный сокет, а не маршрут Rails, потому что метрики нужны и тем
  # процессам, где веб-сервера нет вовсе — потребителю Sneakers и планировщику
  # заданий inbox. Так все процессы всех сервисов отвечают по одному адресу,
  # и конфигурация Prometheus остаётся однообразной
  class Exporter
    PATH = '/metrics'.freeze
    CONTENT_TYPE = 'text/plain; version=0.0.4; charset=utf-8'.freeze
    # Медленный клиент не должен задерживать следующий сбор метрик
    READ_TIMEOUT = 5

    class << self
      def start
        return unless enabled?

        new.start
      end

      private

      def enabled?
        return false unless Settings.metrics.enabled
        # Консоль, rake-задачи и спеки метрик не публикуют
        return false if ProcessInfo.kind.nil?

        true
      end
    end

    attr_reader :server, :thread

    def start
      @server = TCPServer.new('0.0.0.0', Settings.metrics.port.to_i)
      @thread = Thread.new { accept_loop }
      log_started
      self
    rescue Errno::EADDRINUSE => e
      Rails.logger.warn("Метрики: порт #{Settings.metrics.port} уже занят — #{e.message}")
      nil
    end

    def stop
      thread&.kill
      server&.close
    end

    private

    def accept_loop
      loop do
        handle(server.accept)
      rescue IOError, Errno::EBADF
        break
      rescue => e
        Rails.logger.error("Метрики: ошибка обработки запроса — #{e.message}")
      end
    end

    def handle(socket)
      socket.timeout = READ_TIMEOUT

      case request_path(socket)
      when PATH then respond(socket, '200 OK', Health.render)
      when nil then nil
      else respond(socket, '404 Not Found', "Метрики доступны по #{PATH}\n")
      end
    rescue IO::TimeoutError
      Rails.logger.warn('Метрики: клиент не прислал запрос вовремя')
    ensure
      socket.close
    end

    # Заголовки вычитываются целиком, иначе клиент получит ответ вместе
    # со сбросом соединения и посчитает сбор метрик неудачным
    def request_path(socket)
      request_line = socket.gets
      nil while (header = socket.gets) && header != "\r\n" && !header.strip.empty?
      return if request_line.nil?

      request_line.split[1]&.split('?')&.first
    end

    def respond(socket, status, body)
      socket.print(
        "HTTP/1.1 #{status}\r\n" \
        "Content-Type: #{CONTENT_TYPE}\r\n" \
        "Content-Length: #{body.bytesize}\r\n" \
        "Connection: close\r\n\r\n"
      )
      socket.print(body)
    end

    def log_started
      Rails.logger.info(
        "Метрики: процесс #{ProcessInfo.kind} сервиса #{ProcessInfo.service} " \
        "отдаёт метрики на порту #{Settings.metrics.port}"
      )
    end
  end
end
