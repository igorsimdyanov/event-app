# frozen_string_literal: true

RSpec.describe Events::RegisterService do
  subject(:registered_event) { Event.order(:created_at).last }

  let(:attachment_id) { SecureRandom.uuid }
  let(:check) { Check.find_by(attachment_id: attachment_id) }
  let(:message) do
    {
      action: 'pay_analyse',
      created_at: 1_761_736_906,
      routing_key: 'pay_analyse',
      payload: {
        attachment_id: attachment_id,
        file: '5775dae8f4b10.jpeg',
        full_path: 'attachment/2026-07-31/5775dae8f4b10.jpeg',
        message: "ООО Ромашка\nИТОГО: 154.00"
      }
    }
  end

  it 'регистрирует событие' do
    expect { described_class.call(message) }.to change(Event, :count).by(1)
  end

  it 'сохраняет сообщение целиком' do
    described_class.call(message)

    expect(registered_event.data).to eq(message.deep_stringify_keys)
  end

  it 'определяет микросервис-источник события' do
    described_class.call(message)

    expect(registered_event.source).to eq('check-manager')
  end

  describe 'время события' do
    it 'берёт его из конверта сообщения' do
      described_class.call(message)

      expect(registered_event.occurred_at).to eq(Time.zone.at(1_761_736_906))
    end

    it 'разбирает время, переданное строкой' do
      described_class.call(message.merge(created_at: '2026-07-31T18:13:27+03:00'))

      expect(registered_event.occurred_at).to eq(Time.zone.parse('2026-07-31T18:13:27+03:00'))
    end

    it 'подставляет время регистрации, если в строке нет даты' do
      freeze_time do
        described_class.call(message.merge(created_at: 'вчера вечером'))

        expect(registered_event.occurred_at).to eq(Time.current)
      end
    end

    it 'подставляет время регистрации, если дата в строке невозможна' do
      freeze_time do
        described_class.call(message.merge(created_at: '31-31-2026'))

        expect(registered_event.occurred_at).to eq(Time.current)
      end
    end

    it 'подставляет время регистрации, если конверт его не несёт' do
      freeze_time do
        described_class.call(message.except(:created_at))

        expect(registered_event.occurred_at).to eq(Time.current)
      end
    end
  end

  it 'регистрирует событие с неизвестным действием, если конверт его не несёт' do
    described_class.call(message.except(:action))

    expect(registered_event.action).to eq(described_class::UNKNOWN_ACTION)
  end

  it 'записывает фактический ключ маршрутизации доставки' do
    described_class.call(message, routing_key: 'recognized_result')

    expect(registered_event.routing_key).to eq('recognized_result')
  end

  it 'использует ключ из конверта, если ключ доставки неизвестен' do
    described_class.call(message)

    expect(registered_event.routing_key).to eq('pay_analyse')
  end

  describe 'группировка по correlation-id' do
    it 'создаёт чек по attachment_id из сообщения' do
      expect { described_class.call(message) }.to change(Check, :count).by(1)
    end

    it 'подшивает события одной транзакции к одному чеку' do
      described_class.call(message)
      described_class.call(message.deep_merge(action: 'pay_register', created_at: 1_761_736_908))

      expect(check.events.count).to eq(2)
    end

    it 'не плодит чеки для повторных событий' do
      described_class.call(message)

      expect { described_class.call(message) }.not_to change(Check, :count)
    end

    it 'регистрирует событие без correlation-id вне чеков' do
      described_class.call({ action: 'unparsable_message', payload: {} })

      expect(registered_event.check).to be_nil
    end
  end

  describe 'сведения о чеке' do
    it 'накапливает данные о вложении' do
      described_class.call(message)

      expect(check).to have_attributes(
        file: '5775dae8f4b10.jpeg',
        full_path: 'attachment/2026-07-31/5775dae8f4b10.jpeg'
      )
    end

    it 'запоминает стоимость, как только она распознана' do
      described_class.call(message.deep_merge(action: 'budget_check', payload: { price: 1500.0 }))

      expect(check.price).to eq('1500.0')
    end

    it 'не затирает известную стоимость сообщением без неё' do
      described_class.call(message.deep_merge(action: 'budget_check', payload: { price: 1500.0 }))
      described_class.call(message.deep_merge(created_at: 1_761_736_910, payload: { price: nil }))

      expect(check.price).to eq('1500.0')
    end

    it 'отмечает действие последнего события' do
      described_class.call(message)
      described_class.call(message.deep_merge(action: 'pay_register', created_at: 1_761_736_908))

      expect(check.last_action).to eq('pay_register')
    end

    it 'не откатывает статус чека сообщением, пришедшим с опозданием' do
      described_class.call(message.deep_merge(action: 'pay_register', created_at: 1_761_736_908))
      described_class.call(message.deep_merge(created_at: 1_761_736_906))

      expect(check.last_action).to eq('pay_register')
    end

    it 'запоминает границы обработки чека' do
      described_class.call(message)
      described_class.call(message.deep_merge(created_at: 1_761_736_908))

      expect(check).to have_attributes(
        first_event_at: Time.zone.at(1_761_736_906),
        last_event_at: Time.zone.at(1_761_736_908)
      )
    end
  end

  describe 'события с ошибкой' do
    let(:error) { StandardError.new('Ошибка обработки') }

    before { allow(error).to receive(:backtrace).and_return([ 'line 1', 'line 2' ]) }

    it 'помечает событие неуспешным' do
      described_class.call(message, error: error)

      expect(registered_event).to have_attributes(success: false, error_message: 'Ошибка обработки')
    end

    it 'сохраняет стектрейс ошибки' do
      described_class.call(message, error: error)

      expect(registered_event.error_backtrace).to eq("line 1\nline 2")
    end

    it 'учитывает ошибку в чеке' do
      described_class.call(message, error: error)

      expect(check.failed_events_count).to eq(1)
    end
  end
end
