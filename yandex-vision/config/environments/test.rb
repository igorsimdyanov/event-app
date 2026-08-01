require "active_support/core_ext/integer/time"

# Приложение сконфигурировано как минимальное (в config/application.rb
# подключён только active_model). Поэтому здесь нет настроек action_controller,
# action_mailer, active_storage и active_record — соответствующие фреймворки
# не загружены, и обращение к ним привело бы к NoMethodError при загрузке
# тестового окружения.
Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # While tests run files are not watched, reloading is not necessary.
  config.enable_reloading = false

  # Eager loading loads your entire application. When running a single test locally,
  # this is usually not necessary, and can slow down your test suite. However, it's
  # recommended that you enable it in continuous integration systems to ensure eager
  # loading is working properly before deploying your code.
  config.eager_load = ENV["CI"].present?

  # Show full error reports.
  config.consider_all_requests_local = true
  config.cache_store = :null_store

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr
end
