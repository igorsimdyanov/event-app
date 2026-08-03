require 'pry'
require 'pry-byebug'
require 'pathname'

class ::RailsTemplate < Thor::Group
  include Thor::Actions
  include Rails::Generators::Actions

  attr_accessor :options, :args

  #   rabbitmq
  #   aasm
  #   file-detectors
  ACTIONS = %w[
    active-admin
  ].freeze
  #   db

  ACTIONS.each do |action|
    define_method("skip_#{action.underscore}?") do
      args.include? "--skip-#{action}"
    end
  end

  def configure_active_admin
    return if skip_active_admin?

    directory 'app/admin'
    copy_file 'app/models/rabbit_message.rb'
    copy_file 'app/models/concerns/ransackable.rb'
  end

  def configure_configs
    copy_file '.rubocop.yml', force: true
    copy_file '.rspec'
    copy_file 'sample.env'
    copy_file 'config/initializers/config.rb'
    copy_file 'config/initializers/active_admin.rb'
    copy_file 'config/initializers/sneakers.rb'
    copy_file 'config/initializers/rabbitmq.rb'
    copy_file 'config/initializers/carrierwave.rb'
    copy_file 'config/settings.yml'
    copy_file 'config/routes.rb', force: true
    copy_file 'config/locales/ru.active_admin.yml', force: true
  end

  # Гема rails-i18n в проекте нет, поэтому русские правила множественного
  # числа подключаются вручную — без них ActiveAdmin падает на формах
  # one/few/many при обращении к названиям ресурсов
  def configure_locale
    copy_file 'config/initializers/i18n.rb'
    copy_file 'config/locales/plurals.rb'
    copy_file 'config/locales/ru.yml', force: true

    environment <<~RUBY
      config.i18n.available_locales = %i[en ru]
      config.i18n.default_locale = :ru
    RUBY
  end

  def configure_controllers
    copy_file 'app/controllers/application_controller.rb', force: true
  end

  def configure_gemfile
    remove_file 'Gemfile'
    template 'Gemfile.erb', 'Gemfile'
    copy_file 'Rakefile', force: true
  end

  def configure_rabbit_mq
    copy_file 'app/workers/sneakers_listener.rb', force: true
    copy_file 'lib/rabbit_messages/logging.rb', force: true
    copy_file 'lib/rabbit_messages/base_amqp.rb', force: true
    copy_file 'lib/rabbit_messages/send.rb', force: true
    copy_file 'lib/tasks/fake_message.rake', force: true
    copy_file 'lib/rabbit_bind_queues.rb', force: true
    copy_file 'lib/callable.rb', force: true
  end

  # Метрики Prometheus отдаёт каждый долгоживущий процесс сервиса — и панель,
  # и потребитель сообщений, поэтому экспортер входит в общий каркас.
  # Из автозагрузки каталог исключается: экспортер держит фоновый поток,
  # который переживает перезагрузку кода в development
  def configure_metrics
    copy_file 'config/initializers/metrics.rb'
    copy_file 'lib/metrics/process_info.rb'
    copy_file 'lib/metrics/health.rb'
    copy_file 'lib/metrics/exporter.rb'

    gsub_file 'config/application.rb',
              'config.autoload_lib(ignore: %w[assets tasks])',
              'config.autoload_lib(ignore: %w[assets tasks metrics])'
  end

  # Спаны в Zipkin отправляет каждый процесс, который принимает или
  # публикует сообщения, поэтому трассировка тоже входит в общий каркас.
  # Из автозагрузки каталог исключается по той же причине, что и метрики:
  # репортер держит фоновый поток, переживающий перезагрузку кода
  def configure_tracing
    copy_file 'config/initializers/tracing.rb'
    copy_file 'lib/tracing/trace_context.rb'
    copy_file 'lib/tracing/span.rb'
    copy_file 'lib/tracing/null_span.rb'
    copy_file 'lib/tracing/reporter.rb'
    copy_file 'lib/tracing/consumer.rb'
    copy_file 'lib/tracing/tracer.rb'

    gsub_file 'config/application.rb',
              'config.autoload_lib(ignore: %w[assets tasks metrics])',
              'config.autoload_lib(ignore: %w[assets tasks metrics tracing])'
  end

  def configure_gitignore
    copy_file '.gitignore', force: true
  end

  def configure_assets
    copy_file 'app/assets/config/manifest.js', force: true
    copy_file 'app/assets/images/favicon.ico', force: true
    copy_file 'app/assets/javascripts/active_admin.js', force: true
    copy_file 'app/assets/javascripts/jsonb.js', force: true
    copy_file 'app/assets/stylesheets/active_admin.scss', force: true
    copy_file 'app/assets/stylesheets/application.css', force: true
    copy_file 'vendor/assets/javascripts/jquery.json-viewer.js', force: true
    copy_file 'vendor/assets/javascripts/jquery.suggestions.min.js', force: true
    copy_file 'vendor/assets/stylesheets/jquery.json-viewer.scss', force: true
    copy_file 'vendor/assets/stylesheets/suggestions.min.css', force: true
  end

  def copy_fixtures
    copy_file 'spec/fixtures/hello.json', force: true
    copy_file 'spec/rails_helper.rb', force: true
    copy_file 'spec/spec_helper.rb', force: true
  end

  def copy_db_dir
    copy_file 'db/migrate/20250301085819_create_rabbit_messages.rb'
  end

  def copy_readmemd
    remove_file 'readme.md'
    copy_file 'readme.md'
  end

  def self.source_root
    File.join(__dir__, 'templates')
  end

  def app_name
    options[:app_name]
  end

  def ruby_version
    {
      full: RUBY_VERSION,
      major: RUBY_VERSION[/^(\d+\.\d+)\..*?$/, 1]
    }
  end

  def rails_version
    [Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join('.')
  end
end

generator = ::RailsTemplate.new
generator.shell = shell
generator.options = options.merge(app_name: app_name, rails_generator: self)
generator.args = args
generator.destination_root = Dir.pwd
generator.invoke_all

after_bundle do
  run 'bundle exec rails db:drop db:create db:migrate'
  run 'bundle exec rubocop -A --disable-uncorrectable'
end
