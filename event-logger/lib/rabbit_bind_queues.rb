class RabbitBindQueues
  class << self
    def create_for(*workers)
      exchange = channel.exchange(
        Settings.rabbitmq.exchange,
        type: Settings.rabbitmq.exchange_type,
        durable: true
      )

      workers.each do |worker|
        create_queue_for_worker(exchange, worker)
      end
    end

    private

    def channel
      RabbitConnectionManager.channel
    end

    def create_queue_for_worker(exchange, worker_class)
      create_dead_letter_queue(exchange, worker_class)

      queue = channel.queue(
        worker_class::QUEUE_NAME,
        worker_class::ARGUMENTS
      )
      binding_keys(worker_class).each do |r_key|
        queue.bind(exchange, routing_key: r_key)
      end
    end

    # Отклонённые сообщения (reject) уходят в очередь <очередь>.error и ждут
    # там разбора (ADR-0009). Привязка к services нужна лишь тем сервисам,
    # которые направляют dead-letter через этот обменник: сервис с маской `#`
    # использует обменник по умолчанию, чтобы не зациклить сообщение на себе
    def create_dead_letter_queue(exchange, worker_class)
      return unless defined?(worker_class::QUEUE_DEAD_LETTER)

      dead_letter = channel.queue(
        worker_class::QUEUE_DEAD_LETTER,
        durable: true
      )
      return unless dead_letter_exchange(worker_class) == Settings.rabbitmq.exchange

      dead_letter.bind(exchange, routing_key: worker_class::QUEUE_DEAD_LETTER)
    end

    def dead_letter_exchange(worker_class)
      return unless defined?(worker_class::DEAD_LETTER_ARGUMENTS)

      worker_class::DEAD_LETTER_ARGUMENTS['x-dead-letter-exchange']
    end

    # Обычный сервис слушает только свои действия, журнал событий — маску ключей
    def binding_keys(worker_class)
      return worker_class::BINDING_KEYS if defined?(worker_class::BINDING_KEYS)

      worker_class::ACTION_HANDLERS.keys
    end
  end
end
