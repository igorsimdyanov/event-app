Rails.application.routes.draw do
  # Сервис не имеет HTTP-точек входа: это потребитель сообщений RabbitMQ
  # (см. app/workers/sneakers_listener.rb). Маршруты не объявляются.
end
