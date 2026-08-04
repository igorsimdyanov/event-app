module Tracing
  # Приём сообщения глазами трассировки: спан на каждое сообщение, взятое
  # из очереди. Подмешивается в воркеры Sneakers — у сервиса их бывает
  # несколько, а обёртка у всех одна
  module Consumer
    private

    # Имя спана даёт маршрутный ключ доставки: он точнее поля routing_key
    # в конверте и различает ответы, отправленные через reply_to
    def trace_message(delivery_info, metadata, message, &)
      Tracing.consumer_span(
        delivery_info&.routing_key,
        headers: metadata&.headers,
        message: message,
        tags: { queue: self.class::QUEUE_NAME },
        &
      )
    end
  end
end
