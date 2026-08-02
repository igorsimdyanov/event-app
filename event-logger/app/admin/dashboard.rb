# rubocop:disable Metrics/BlockLength
ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: proc { t('active_admin.dashboard') }

  content title: proc { I18n.t('active_admin.dashboard') } do
    columns do
      column do
        panel t('active_admin.dashboard_stats.totals') do
          table_for Dashboard::TotalsService.call do
            column(t('active_admin.dashboard_stats.metric')) { |row| row.first }
            column(t('active_admin.dashboard_stats.value')) { |row| row.last }
          end
        end
      end

      column do
        panel t('active_admin.dashboard_stats.by_action') do
          table_for Event.group(:action).count.sort_by { |_action, count| -count } do
            column(t('activerecord.attributes.event.action')) { |row| row.first }
            column(t('active_admin.dashboard_stats.value')) { |row| row.last }
          end
        end
      end

      column do
        panel t('active_admin.dashboard_stats.by_source') do
          table_for Event.group(:source).count.sort_by { |_source, count| -count } do
            column(t('activerecord.attributes.event.source')) { |row| row.first }
            column(t('active_admin.dashboard_stats.value')) { |row| row.last }
          end
        end
      end
    end

    panel t('active_admin.dashboard_stats.last_receipts') do
      table_for Receipt.recent.limit(10) do
        column(:attachment_id) { |receipt| link_to receipt.attachment_id, admin_receipt_path(receipt) }
        column(:file)
        column(:price)
        column(:last_action) do |receipt|
          status_tag receipt.last_action, class: receipt.failed? ? 'error' : 'success'
        end
        column(:events_count)
        column(:last_event_at)
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
