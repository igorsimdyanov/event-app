require 'json'
require 'net/http'

module Tracing
  # Доставка спанов в Zipkin. Собственный фоновый поток с очередью, а не
  # отправка на месте: HTTP-запрос к коллектору не должен ни задерживать
  # обработку сообщения, ни ронять её, если коллектор недоступен
  class Reporter
    PATH = '/api/v2/spans'.freeze
    CONTENT_TYPE = 'application/json'.freeze
    # Накопленные спаны уходят пачкой: по её заполнении или по таймауту,
    # чтобы одинокий спан не ждал в очереди неопределённо долго
    BATCH_LIMIT = 100
    FLUSH_INTERVAL = 2
    # Очередь ограничена: при недоступном Zipkin спаны копятся быстрее,
    # чем уходят, и память конвейера дороже полноты трасс
    QUEUE_LIMIT = 2_000
    OPEN_TIMEOUT = 2
    READ_TIMEOUT = 5

    class << self
      def start
        @instance ||= new.start
      end

      def report(span)
        @instance&.push(span)
      end

      def started?
        !@instance.nil?
      end

      def stop
        @instance&.stop
        @instance = nil
      end
    end

    attr_reader :queue, :thread

    def initialize
      @queue = Queue.new
      @mutex = Mutex.new
      @dropped = 0
      @available = true
    end

    def start
      @owner_pid = ::Process.pid
      @thread = Thread.new { flush_loop }
      Rails.logger.info(
        "Трассировка: спаны сервиса #{Metrics::ProcessInfo.service} уходят в #{endpoint}"
      )
      self
    end

    def stop
      thread&.kill
    end

    def push(span)
      restart_after_fork unless @owner_pid == ::Process.pid
      return drop if queue.size >= QUEUE_LIMIT

      queue << span
    end

    private

    # Sneakers запускает воркеров отдельными процессами, а потоки fork не
    # переживают: в потомке остаётся мёртвый поток отправки и очередь,
    # которую некому разбирать. Спаны родителя достались копией — они
    # отправлены им же, поэтому потомок начинает с пустой очереди
    def restart_after_fork
      @mutex.synchronize do
        return if @owner_pid == ::Process.pid

        @queue = Queue.new
        start
      end
    end

    def flush_loop
      buffer = []
      loop do
        span = queue.pop(timeout: FLUSH_INTERVAL)
        buffer << span if span
        # Пока спаны идут потоком, пачка добирается до предела; пауза в
        # трафике (pop вернул nil) отправляет её недобранной
        next if buffer.empty? || (span && buffer.size < BATCH_LIMIT)

        deliver(buffer)
        buffer = []
      end
    rescue => e
      Rails.logger.error("Трассировка: поток отправки остановлен — #{e.message}")
    end

    def deliver(spans)
      response = post(spans.map(&:to_h))
      return note_failure("Zipkin ответил #{response.code}") unless response.is_a?(Net::HTTPSuccess)

      note_success
    rescue => e
      note_failure(e.message)
    end

    def post(payload)
      request = Net::HTTP::Post.new(PATH, 'Content-Type' => CONTENT_TYPE)
      request.body = payload.to_json

      Net::HTTP.start(
        Settings.tracing.host,
        Settings.tracing.port.to_i,
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      ) do |http|
        http.request(request)
      end
    end

    def drop
      @dropped += 1
      # Об отброшенных спанах сообщается редко: очередь переполняется
      # надолго, и запись о каждом потерянном спане засорила бы журнал
      return unless (@dropped % QUEUE_LIMIT).zero?

      Rails.logger.warn("Трассировка: очередь переполнена, отброшено спанов — #{@dropped}")
    end

    # Недоступность коллектора отмечается один раз, а не каждые несколько
    # секунд: журнал сервиса ведётся ради конвейера, а не ради трассировки
    def note_failure(reason)
      return unless @available

      @available = false
      Rails.logger.warn("Трассировка: #{endpoint} не принимает спаны — #{reason}")
    end

    def note_success
      return if @available

      @available = true
      Rails.logger.info("Трассировка: #{endpoint} снова принимает спаны")
    end

    def endpoint
      "http://#{Settings.tracing.host}:#{Settings.tracing.port}#{PATH}"
    end
  end
end
