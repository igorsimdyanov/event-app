require 'securerandom'

module Tracing
  # Контекст трассировки в формате B3 (соглашение openzipkin): между
  # сервисами он переезжает заголовками AMQP-сообщения, внутри процесса
  # живёт в текущем спане.
  #
  # Идентификатор трассы не выдумывается: им служит attachment_id —
  # сквозной correlation-id бизнес-транзакции (ADR-0004). UUID без дефисов
  # это ровно 32 шестнадцатеричные цифры, то есть готовый 128-битный
  # traceId Zipkin, поэтому по номеру вложения сразу открывается его трасса
  class TraceContext
    TRACE_ID_HEADER = 'X-B3-TraceId'.freeze
    SPAN_ID_HEADER = 'X-B3-SpanId'.freeze
    PARENT_SPAN_ID_HEADER = 'X-B3-ParentSpanId'.freeze
    SAMPLED_HEADER = 'X-B3-Sampled'.freeze
    SAMPLED = '1'.freeze
    NOT_SAMPLED = '0'.freeze
    # Длина идентификаторов в шестнадцатеричных цифрах: 128 бит у трассы,
    # 64 бита у спана
    TRACE_ID_LENGTH = 32
    SPAN_ID_LENGTH = 16
    HEX = /\A\h+\z/

    class << self
      # Заголовки приходят от брокера как есть, поэтому регистр ключей не
      # гарантирован: B3 допускает и X-B3-TraceId, и x-b3-traceid
      def from_headers(headers)
        return if headers.blank?

        values = headers.transform_keys { |key| key.to_s.downcase }
        trace_id = normalize_trace_id(values[TRACE_ID_HEADER.downcase])
        return if trace_id.nil?

        new(
          trace_id: trace_id,
          parent_span_id: values[SPAN_ID_HEADER.downcase],
          sampled: values[SAMPLED_HEADER.downcase] != NOT_SAMPLED
        )
      end

      # Сообщение без заголовков трассировки — начало трассы: его отправил
      # тот, у кого контекста не было (планировщик inbox, админка,
      # rake-задача). Трассу всё равно склеит attachment_id
      def from_message(message)
        new(trace_id: trace_id_from(message))
      end

      def generate_span_id
        SecureRandom.hex(SPAN_ID_LENGTH / 2)
      end

      # Ключи сообщения бывают и символами (JSON разбирается с
      # symbolize_names), и строками — сериализатор inbox отдаёт строки
      def correlation_id(message)
        return unless message.is_a?(Hash)

        message.dig(:payload, :attachment_id) || message.dig('payload', 'attachment_id')
      end

      private

      def trace_id_from(message)
        normalize_trace_id(correlation_id(message)) || SecureRandom.hex(TRACE_ID_LENGTH / 2)
      end

      def normalize_trace_id(value)
        hex = value.to_s.delete('-').downcase
        return unless [TRACE_ID_LENGTH, SPAN_ID_LENGTH].include?(hex.length) && hex.match?(HEX)

        hex
      end
    end

    attr_reader :trace_id, :parent_span_id

    def initialize(trace_id:, parent_span_id: nil, sampled: true)
      @trace_id = trace_id
      @parent_span_id = parent_span_id.presence
      @sampled = sampled
    end

    def sampled?
      @sampled
    end
  end
end
