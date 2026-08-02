# frozen_string_literal: true

RSpec.describe 'Панель администрирования', type: :request do
  let(:check) { create(:check, attachment_id: SecureRandom.uuid, price: '1500.0') }

  let!(:registered) do
    create(:event, check: check, action: 'attachment_registered', source: 'inbox',
      occurred_at: Time.zone.at(1_761_736_890))
  end
  let!(:analysed) do
    create(:event, check: check, action: 'pay_analyse', source: 'check-manager',
      occurred_at: Time.zone.at(1_761_736_906))
  end
  let!(:registered_pay) do
    create(:event, check: check, action: 'pay_register', source: 'budget-control',
      occurred_at: Time.zone.at(1_761_736_908))
  end

  describe 'главная страница' do
    it 'открывается без авторизации' do
      get '/admin'

      expect(response).to have_http_status(:ok)
    end

    it 'показывает сводку по журналу' do
      get '/admin'

      expect(response.body).to include(I18n.t('active_admin.dashboard_stats.totals'))
    end

    it 'показывает последние чеки' do
      get '/admin'

      expect(response.body).to include(check.attachment_id)
    end
  end

  describe 'список чеков' do
    it 'открывается' do
      get '/admin/checks'

      expect(response).to have_http_status(:ok)
    end

    it 'показывает чек с его correlation-id' do
      get '/admin/checks'

      expect(response.body).to include(check.attachment_id)
    end

    it 'находит чек по части correlation-id' do
      get '/admin/checks', params: { q: { attachment_id_text_cont: check.attachment_id.first(8) } }

      expect(response.body).to include("/admin/checks/#{check.id}")
    end

    it 'не показывает чеки, не подошедшие под фильтр' do
      other = create(:check)

      get '/admin/checks', params: { q: { attachment_id_text_cont: check.attachment_id.first(8) } }

      expect(response.body).not_to include("/admin/checks/#{other.id}")
    end
  end

  describe 'страница чека' do
    it 'открывается' do
      get "/admin/checks/#{check.id}"

      expect(response).to have_http_status(:ok)
    end

    it 'показывает хронологию событий по чеку' do
      get "/admin/checks/#{check.id}"

      expect(response.body).to include(I18n.t('active_admin.event_timeline'))
    end

    it 'перечисляет события в хронологическом порядке' do
      get "/admin/checks/#{check.id}"

      timeline = response.body.split(I18n.t('active_admin.event_timeline')).last
      positions = %w[attachment_registered pay_analyse pay_register].map { |action| timeline.index(action) }

      expect(positions).to eq(positions.compact.sort)
    end

    it 'показывает микросервисы-источники событий' do
      get "/admin/checks/#{check.id}"

      expect(response.body).to include('inbox', 'check-manager', 'budget-control')
    end

    it 'показывает задержку между шагами' do
      get "/admin/checks/#{check.id}"

      expect(response.body).to include('+16,0 c')
    end
  end

  describe 'журнал событий' do
    it 'открывается' do
      get '/admin/events'

      expect(response).to have_http_status(:ok)
    end

    it 'связывает событие с его чеком' do
      get '/admin/events'

      expect(response.body).to include("/admin/checks/#{check.id}")
    end

    it 'фильтрует события по действию' do
      get '/admin/events', params: { q: { action_eq: 'pay_analyse' } }

      expect(response.body).to include("/admin/events/#{analysed.id}")
    end

    it 'не показывает события с другим действием' do
      get '/admin/events', params: { q: { action_eq: 'pay_analyse' } }

      expect(response.body).not_to include("/admin/events/#{registered.id}")
    end

    it 'показывает событие целиком' do
      get "/admin/events/#{analysed.id}"

      expect(response).to have_http_status(:ok)
    end

    it 'показывает correlation-id события, не привязанного к чеку' do
      orphan = create(:event, check: nil, attachment_id: SecureRandom.uuid)

      get '/admin/events'

      expect(response.body).to include(orphan.attachment_id)
    end
  end
end
