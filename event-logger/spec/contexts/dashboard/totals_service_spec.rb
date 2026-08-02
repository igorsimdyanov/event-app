# frozen_string_literal: true

RSpec.describe Dashboard::TotalsService do
  subject(:totals) { described_class.call.to_h }

  def value_of(key)
    totals[I18n.t("active_admin.dashboard_stats.#{key}")]
  end

  context 'когда журнал пуст' do
    it 'сообщает, что чеков нет' do
      expect(value_of(:checks)).to eq(0)
    end

    it 'сообщает, что событий нет' do
      expect(value_of(:events)).to eq(0)
    end

    it 'не показывает время последнего события' do
      expect(value_of(:last_event_at)).to be_nil
    end
  end

  context 'когда события зарегистрированы' do
    let(:check) { create(:check) }

    before do
      create(:event, check: check, occurred_at: Time.zone.at(1_761_736_906))
      create(:event, :failed, check: check, occurred_at: Time.zone.at(1_761_736_908))
      create(:event, check: create(:check), occurred_at: Time.zone.at(1_761_736_900))
    end

    it 'считает чеки' do
      expect(value_of(:checks)).to eq(2)
    end

    it 'считает события' do
      expect(value_of(:events)).to eq(3)
    end

    it 'отдельно считает события с ошибкой' do
      expect(value_of(:failed_events)).to eq(1)
    end

    it 'показывает время последнего события в локальном формате' do
      expect(value_of(:last_event_at))
        .to eq(I18n.l(Time.zone.at(1_761_736_908), format: :long))
    end
  end
end
