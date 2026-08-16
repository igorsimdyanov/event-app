require_relative 'trace_context'
require_relative '../metrics/process_info'

module Tracing
  # Отрезок работы одного сервиса в модели Zipkin v2: приём сообщения из
  # очереди или его публикация. Спаны одной трассы связывает parentId,
  # поэтому Zipkin рисует конвейер деревом, а не списком записей
  class Span
    CONSUMER = 'CONSUMER'.freeze
    PRODUCER = 'PRODUCER'.freeze
    ERROR_TAG = 'error'.freeze
    PROCESS_TAG = 'process'.freeze
    BROKER_TAG = 'broker'.freeze
    BROKER = 'rabbitmq'.freeze
    MICROSECONDS = 1_000_000

    attr_reader :trace_id, :id, :parent_id, :name, :kind, :remote, :tags

    def initialize(name:, kind:, context:, remote:, tags: {})
      @name = name
      @kind = kind
      @context = context
      @remote = remote
      @trace_id = context.trace_id
      @parent_id = context.parent_span_id
      @id = TraceContext.generate_span_id
      @tags = stringify(tags).merge(
        PROCESS_TAG => Metrics::ProcessInfo.kind.to_s,
        BROKER_TAG => BROKER
      )
    end

    def start
      # Начало спана — во времени Unix (его показывает Zipkin),
      # длительность — по монотонным часам: перевод системного времени
      # не должен превращать обработку в отрицательную
      @timestamp = (Time.now.to_f * MICROSECONDS).round
      @started_at = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      self
    end

    def finish
      elapsed = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - @started_at
      @duration = (elapsed * MICROSECONDS).round
      self
    end

    def sampled?
      @context.sampled?
    end

    def tag(name, value)
      tags[name.to_s] = value.to_s
      self
    end

    def failed(exception)
      tag(ERROR_TAG, exception.message)
    end

    # Заголовки сообщения, отправленного внутри этого спана: получатель
    # сделает его своим родителем и продолжит ту же трассу
    def headers
      {
        TraceContext::TRACE_ID_HEADER => trace_id,
        TraceContext::SPAN_ID_HEADER => id,
        TraceContext::PARENT_SPAN_ID_HEADER => parent_id,
        TraceContext::SAMPLED_HEADER => sampled? ? TraceContext::SAMPLED : TraceContext::NOT_SAMPLED
      }.compact
    end

    # Контекст для спана-потомка внутри того же процесса: публикация,
    # начатая при обработке сообщения, продолжает его спан
    def child_context
      TraceContext.new(trace_id: trace_id, parent_span_id: id, sampled: sampled?)
    end

    def to_h
      {
        traceId: trace_id,
        id: id,
        parentId: parent_id,
        name: name,
        kind: kind,
        timestamp: @timestamp,
        duration: @duration,
        localEndpoint: {serviceName: Metrics::ProcessInfo.service},
        remoteEndpoint: remote_endpoint,
        tags: tags
      }.compact
    end

    private

    # Удалённый конец обмена — маршрутный ключ сообщения, а не брокер:
    # по нему Zipkin строит граф зависимостей, и каналы становятся в нём
    # отдельными узлами между сервисами (ADR-0011). Имя самого брокера
    # остаётся тегом. Спан без этого поля в граф не попадает вовсе —
    # так из схемы исключаются сервисы, которые её только зашумляют
    def remote_endpoint
      return if remote.blank?

      {serviceName: remote}
    end

    def stringify(tags)
      tags.compact.to_h { |name, value| [name.to_s, value.to_s] }
    end
  end
end
