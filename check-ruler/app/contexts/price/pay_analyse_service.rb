class Price::PayAnalyseService
  include Callable
  extend Dry::Initializer

  param :message

  def call
    price = Price::ExtractService.call(recognized_check)

    if price.nil? || price > 200
      # Бюджетный контроль. Сюда же попадают чеки, в которых сумму не удалось
      # распознать (price == nil): решение принимает держатель бюджета вручную.
      routing_key = 'budget_check'
      topic = 'budget_control.in'
    else
      # Регистрируем без контроля
      routing_key = 'pay_register'
      topic = 'register.in'
    end
    next_message = Price::BuildMessageService.call(
                     message: message,
                     price: price,
                     routing_key: routing_key)

    RabbitMessages::Send.call(next_message, topic)
  end

  def recognized_check
    # Tesseract
    result = message&.dig(:payload, :message)
    # Yandex Vison
    if result.respond_to?(:to_hash)
      result = message&.dig(:payload, :message, :result, :textAnnotation, :fullText)
    end
    result
  end
end
