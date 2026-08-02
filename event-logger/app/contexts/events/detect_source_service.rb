class Events::DetectSourceService
  include Callable
  extend Dry::Initializer

  param :message

  # Микросервисы-продюсеры, однозначно определяемые по действию сообщения
  SOURCES = {
    'attachment_registered' => 'inbox',
    'recognize' => 'check-manager',
    'pay_analyse' => 'check-manager',
    'budget_check' => 'check-ruler'
  }.freeze

  def call
    case action
    when 'recognized_result' then recognizer
    when 'pay_register' then registrar
    else SOURCES[action]
    end
  end

  private

  def envelope
    @envelope ||= message.to_h.with_indifferent_access
  end

  def payload
    @payload ||= (envelope[:payload] || {}).with_indifferent_access
  end

  def action
    envelope[:action].to_s
  end

  # Tesseract отвечает распознанным текстом строкой, Yandex Vision — объектом ответа OCR
  def recognizer
    payload[:message].is_a?(Hash) ? 'yandex-vision' : 'tesseract'
  end

  # budget-control публикует сокращённый payload — без file, created_at и message
  def registrar
    payload.key?(:file) || payload.key?(:message) ? 'check-ruler' : 'budget-control'
  end
end
