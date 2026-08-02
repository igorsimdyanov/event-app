class Events::RegisterService
  include Callable
  extend Dry::Initializer

  UNKNOWN_ACTION = 'unknown'.freeze

  param :message
  option :routing_key, default: -> {}
  option :error, default: -> {}

  # Регистрирует событие и подшивает его к чеку с тем же correlation-id
  def call
    ActiveRecord::Base.transaction do
      check = attachment_id.present? ? Check.for_correlation(attachment_id) : nil
      event = create_event(check)
      refresh_check(check.reload, event) if check

      event
    end
  end

  private

  def create_event(check)
    Event.create!(
      check: check,
      attachment_id: attachment_id,
      action: action,
      routing_key: routing_key.presence || envelope[:routing_key],
      source: Events::DetectSourceService.call(envelope),
      data: envelope,
      occurred_at: occurred_at,
      success: error.blank?,
      error_message: error&.message,
      error_backtrace: error&.backtrace&.join("\n")
    )
  end

  # Чек накапливает сведения о вложении по мере прохождения конвейера
  def refresh_check(check, event)
    check.file = payload[:file] if payload[:file].present?
    check.full_path = payload[:full_path] if payload[:full_path].present?
    check.price = payload[:price] unless payload[:price].nil?
    check.failed_events_count += 1 unless event.success?
    check.first_event_at = [ check.first_event_at, event.occurred_at ].compact.min
    check.last_action = event.action if last_event?(check, event)
    check.last_event_at = [ check.last_event_at, event.occurred_at ].compact.max
    check.save!
  end

  def last_event?(check, event)
    check.last_event_at.blank? || event.occurred_at.blank? ||
      event.occurred_at >= check.last_event_at
  end

  def envelope
    @envelope ||= message.to_h.with_indifferent_access
  end

  def payload
    @payload ||= (envelope[:payload].presence || {}).with_indifferent_access
  end

  def action
    envelope[:action].presence || UNKNOWN_ACTION
  end

  def attachment_id
    payload[:attachment_id]
  end

  # Сообщения несут время создания в источнике (Unix timestamp, UTC) — оно
  # и задаёт хронологию событий по чеку
  def occurred_at
    timestamp = envelope[:created_at]

    case timestamp
    when Integer then Time.zone.at(timestamp)
    when String then Time.zone.parse(timestamp) || Time.current
    else Time.current
    end
  rescue ArgumentError
    Time.current
  end
end
