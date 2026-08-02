# Сводные показатели журнала событий для главной страницы админки
class Dashboard::TotalsService
  include Callable

  def call
    [
      [ I18n.t('active_admin.dashboard_stats.receipts'), Receipt.count ],
      [ I18n.t('active_admin.dashboard_stats.events'), Event.count ],
      [ I18n.t('active_admin.dashboard_stats.failed_events'), Event.failed.count ],
      [ I18n.t('active_admin.dashboard_stats.last_event_at'), last_event_at ]
    ]
  end

  private

  def last_event_at
    occurred_at = Event.maximum(:occurred_at)

    I18n.l(occurred_at.in_time_zone, format: :long) if occurred_at
  end
end
