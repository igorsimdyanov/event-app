# Трассировка подключается напрямую, а не автозагрузкой: репортер держит
# фоновый поток, который переживает перезагрузку кода в development,
# поэтому каталог lib/tracing исключён из autoload_lib в application.rb
require Rails.root.join('lib/tracing/tracer').to_s

Rails.application.config.after_initialize do
  Tracing.start
end
