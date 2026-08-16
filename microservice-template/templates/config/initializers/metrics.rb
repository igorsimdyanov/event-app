# Экспортер метрик подключается напрямую, а не автозагрузкой: он держит
# фоновый поток, который переживает перезагрузку кода в development,
# поэтому каталог lib/metrics исключён из autoload_lib в application.rb
require Rails.root.join('lib', 'metrics', 'exporter').to_s

Rails.application.config.after_initialize do
  Metrics::Exporter.start
end
