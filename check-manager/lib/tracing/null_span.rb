module Tracing
  # Спан-пустышка для процессов, где трассировка выключена или не
  # запускалась (консоль, rake-задачи, спеки). Вызывающий код не проверяет
  # состояние трассировки: он всегда получает спан, просто этот никуда
  # не отправляется и не добавляет сообщению заголовков
  class NullSpan
    class << self
      def instance
        @instance ||= new
      end
    end

    def headers
      {}
    end

    def tag(_name, _value)
      self
    end

    def failed(_exception)
      self
    end
  end
end
