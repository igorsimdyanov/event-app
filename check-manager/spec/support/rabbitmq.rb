# frozen_string_literal: true

# Воркеры при загрузке связывают очереди с обменником
# (`RabbitBindQueues.create_for(...)`), а исходящие сообщения публикуются
# в реальный обменник. В тестах брокер недоступен, поэтому подменяем канал
# RabbitMQ null-объектом: методы объявления/привязки очередей и публикации
# становятся безопасными no-op. Отдельные примеры при необходимости
# переопределяют `RabbitConnectionManager.channel` своими двойниками.
module RabbitMqTestDoubles
  class NullQueue
    def bind(*)
      self
    end
  end

  class NullExchange
    def publish(*)
      nil
    end
  end

  class NullChannel
    def exchange(*)
      NullExchange.new
    end

    def queue(*)
      NullQueue.new
    end

    def open?
      true
    end

    def close
      nil
    end
  end
end

RabbitConnectionManager.define_singleton_method(:channel) do
  RabbitMqTestDoubles::NullChannel.new
end

# Загружаем воркеры сейчас, пока канал — безопасный null-объект. Иначе их
# побочный эффект при загрузке (`RabbitBindQueues.create_for` в конце файла)
# сработает позднее — внутри примера, где канал подменён двойником, — и добавит
# лишние вызовы. Явная загрузка здесь делает автозагрузку в примерах ненужной.
[InboxListener, RecognizerListener].each(&:name)
