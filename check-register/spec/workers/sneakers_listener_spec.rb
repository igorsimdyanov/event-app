# frozen_string_literal: true

RSpec.describe SneakersListener do
  subject(:worker) { described_class.new }

  # Воркер принимает сообщение методом work_with_params: сведения о доставке
  # дают маршрутный ключ, properties — заголовки трассировки (ADR-0011)
  let(:delivery_info) { instance_double(Bunny::DeliveryInfo, routing_key: 'pay_register') }
  let(:metadata) { instance_double(Bunny::MessageProperties, headers: nil) }

  let(:parsed_message) do
    { action: 'pay_register', payload: { price: '250.00', attachment_id: SecureRandom.uuid } }
  end
  let(:message) { parsed_message.to_json }

  before do
    allow(worker).to receive(:ack!)
    allow(worker).to receive(:reject!)
    allow(Checks::RegisterService).to receive(:call)
  end

  describe '#work_with_params' do
    context 'когда action поддерживается' do
      it 'создаёт входящую запись RabbitMessage' do
        expect { worker.work_with_params(message, delivery_info, metadata) }
          .to change { RabbitMessage.income.count }.by(1)
      end

      it 'передаёт распарсенное сообщение обработчику Checks::RegisterService' do
        worker.work_with_params(message, delivery_info, metadata)
        expect(Checks::RegisterService).to have_received(:call).with(parsed_message)
      end

      it 'помечает запись успешно обработанной' do
        worker.work_with_params(message, delivery_info, metadata)
        expect(RabbitMessage.last).to have_attributes(action: 'pay_register', success: true)
      end

      it 'подтверждает обработку сообщения (ack)' do
        worker.work_with_params(message, delivery_info, metadata)
        expect(worker).to have_received(:ack!)
      end
    end

    context 'когда action не поддерживается' do
      let(:message) { { action: 'unknown_action', payload: {} }.to_json }

      it 'отклоняет сообщение (reject)' do
        worker.work_with_params(message, delivery_info, metadata)
        expect(worker).to have_received(:reject!)
      end

      it 'не подтверждает обработку' do
        worker.work_with_params(message, delivery_info, metadata)
        expect(worker).not_to have_received(:ack!)
      end

      it 'помечает запись как неуспешно обработанную' do
        worker.work_with_params(message, delivery_info, metadata)
        expect(RabbitMessage.last.success).to be(false)
      end

      it 'не вызывает обработчик регистрации' do
        worker.work_with_params(message, delivery_info, metadata)
        expect(Checks::RegisterService).not_to have_received(:call)
      end
    end
  end
end
