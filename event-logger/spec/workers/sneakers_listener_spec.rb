# frozen_string_literal: true

RSpec.describe SneakersListener do
  subject(:worker) { described_class.new }

  let(:attachment_id) { SecureRandom.uuid }
  let(:parsed_message) do
    {
      action: 'pay_register',
      created_at: 1_761_736_908,
      routing_key: 'pay_register',
      payload: { price: '250.00', attachment_id: attachment_id }
    }
  end
  let(:message) { parsed_message.to_json }
  let(:delivery_info) { instance_double(Bunny::DeliveryInfo, routing_key: 'pay_register') }

  before do
    allow(worker).to receive(:ack!)
    allow(worker).to receive(:reject!)
  end

  describe '#work_with_params' do
    context 'когда сообщение разобрано' do
      it 'регистрирует событие' do
        expect { worker.work_with_params(message, delivery_info, {}) }.to change(Event, :count).by(1)
      end

      it 'группирует событие по correlation-id' do
        worker.work_with_params(message, delivery_info, {})

        expect(Check.find_by(attachment_id: attachment_id).events.count).to eq(1)
      end

      it 'сохраняет ключ маршрутизации доставки' do
        worker.work_with_params(message, delivery_info, {})

        expect(Event.order(:created_at).last.routing_key).to eq('pay_register')
      end

      it 'подтверждает обработку сообщения (ack)' do
        worker.work_with_params(message, delivery_info, {})

        expect(worker).to have_received(:ack!)
      end
    end

    context 'когда сообщение не удалось разобрать' do
      let(:message) { 'не json' }

      it 'фиксирует сбой в журнале событий' do
        worker.work_with_params(message, delivery_info, {})

        expect(Event.order(:created_at).last).to have_attributes(
          action: described_class::UNPARSABLE_ACTION,
          success: false
        )
      end

      it 'сохраняет исходное сообщение' do
        worker.work_with_params(message, delivery_info, {})

        expect(Event.order(:created_at).last.payload).to include('raw' => 'не json')
      end

      it 'отклоняет сообщение (reject)' do
        worker.work_with_params(message, delivery_info, {})

        expect(worker).to have_received(:reject!)
      end

      it 'не подтверждает обработку' do
        worker.work_with_params(message, delivery_info, {})

        expect(worker).not_to have_received(:ack!)
      end
    end

    context 'когда событие не удалось сохранить' do
      before { allow(Events::RegisterService).to receive(:call).and_raise(StandardError, 'Сбой записи') }

      it 'отклоняет сообщение (reject)' do
        worker.work_with_params(message, delivery_info, {})

        expect(worker).to have_received(:reject!)
      end

      it 'не роняет воркер, если и запись об ошибке не сохранилась' do
        expect { worker.work_with_params(message, delivery_info, {}) }.not_to raise_error
      end
    end

    context 'когда соединение с базой данных потеряно' do
      let(:connection) { ActiveRecord::Base.connection }

      before do
        allow(worker).to receive(:sleep)
        allow(worker).to receive(:requeue!)
        allow(connection).to receive(:reconnect!)
        allow(Events::RegisterService).to receive(:call).and_raise(PG::ConnectionBad, 'connection lost')
      end

      it 'переподключается к базе данных' do
        worker.work_with_params(message, delivery_info, {})

        expect(connection).to have_received(:reconnect!)
      end

      it 'возвращает сообщение в очередь (requeue)' do
        worker.work_with_params(message, delivery_info, {})

        expect(worker).to have_received(:requeue!)
      end

      it 'не подтверждает и не отклоняет сообщение' do
        worker.work_with_params(message, delivery_info, {})

        expect(worker).not_to have_received(:ack!)
        expect(worker).not_to have_received(:reject!)
      end

      it 'повторяет попытку, пока переподключение не удастся' do
        attempts = 0
        allow(connection).to receive(:reconnect!) do
          attempts += 1
          raise PG::UnableToSend, 'still down' if attempts < 3
        end

        worker.work_with_params(message, delivery_info, {})

        expect(attempts).to eq(3)
      end
    end
  end
end
