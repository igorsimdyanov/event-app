# frozen_string_literal: true

# Воркер при загрузке связывает очередь с обменником
# (`RabbitBindQueues.create_for(SneakersListener)` в конце файла), а исходящие
# сообщения публикуются в реальный обменник. В тестах брокер недоступен, поэтому
# подменяем канал RabbitMQ null-объектом: объявление/привязка очередей и
# публикация становятся безопасными no-op. Отдельные примеры при необходимости
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

# Загружаем воркер сейчас, пока канал — безопасный null-объект, чтобы его
# побочный эффект при загрузке (`RabbitBindQueues.create_for`) не сработал
# позднее внутри примера с подменённым каналом.
[SneakersListener].each(&:name)
