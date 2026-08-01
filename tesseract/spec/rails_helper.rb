require 'spec_helper'
ENV['RAILS_ENV'] = 'test'
require_relative '../config/environment'
abort('The Rails environment is running in production mode!') if Rails.env.production?

# Приложение сконфигурировано как минимальное (в config/application.rb подключён
# только active_model, без ActiveRecord/ActionController). Полный `rspec/rails`
# тянет интеграцию со всеми фреймворками Rails и падает без них, поэтому не
# подключаем его: компоненты сервиса — обычные Ruby-объекты (сервисы, воркер,
# менеджеры), для которых достаточно rspec-core/expectations/mocks и загруженного
# окружения приложения.

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories.
Rails.root.glob('spec/support/**/*.rb').sort.each { |f| require f }
