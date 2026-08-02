namespace :fake_message do
  desc 'Тестовый жизненный цикл чека: публикует цепочку событий одной бизнес-транзакции'
  task start: :environment do
    attachment_id = ENV.fetch('ATTACHMENT_ID', SecureRandom.uuid)
    created_at = Time.current.to_i
    file = '5775dae8f4b10.jpeg'
    full_path = "attachment/#{Time.current.strftime('%Y-%m-%d')}/#{file}"
    payload = { attachment_id: attachment_id, file: file, full_path: full_path, created_at: created_at }

    messages = [
      { action: 'attachment_registered', payload: payload.merge(md5: SecureRandom.hex(16)) },
      { action: 'recognize', payload: payload, reply_to: 'recognized_result' },
      { action: 'recognized_result', payload: payload.merge(message: "ООО Ромашка\nИТОГО: 1500.00") },
      { action: 'pay_analyse', payload: payload.merge(message: "ООО Ромашка\nИТОГО: 1500.00") },
      { action: 'budget_check', payload: payload.merge(message: "ООО Ромашка\nИТОГО: 1500.00", price: 1500.0) },
      { action: 'pay_register', payload: { attachment_id: attachment_id, full_path: full_path, price: 1500.0 } }
    ]

    connection = Bunny.new(Settings.rabbitmq.to_hash).start
    channel = connection.create_channel
    exchange = channel.topic(Settings.rabbitmq.exchange, durable: true)

    messages.each_with_index do |message, index|
      envelope = message.merge(created_at: created_at + index * 2, routing_key: message[:action])
      # Публикация с ключом очереди сервиса: событие увидит только журнал,
      # остальные микросервисы конвейера не потревожены
      exchange.publish(envelope.to_json, routing_key: Settings.sneakers.queue)
      puts "Отправлено: #{envelope[:action]}"
    end

    connection.close
    puts "Correlation-id чека: #{attachment_id}"
  end
end
