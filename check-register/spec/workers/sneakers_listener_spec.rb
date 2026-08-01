# frozen_string_literal: true

RSpec.describe SneakersListener do
  subject(:worker) { described_class.new }

  let(:parsed_message) do
    { action: 'pay_register', payload: { price: '250.00', attachment_id: SecureRandom.uuid } }
  end
  let(:message) { parsed_message.to_json }

  before do
    allow(worker).to receive(:ack!)
    allow(worker).to receive(:reject!)
    allow(Checks::RegisterService).to receive(:call)
  end

  describe '#work' do
    context 'когда action поддерживается' do
      it 'создаёт входящую запись RabbitMessage' do
        expect { worker.work(message) }.to change { RabbitMessage.income.count }.by(1)
      end

      it 'передаёт распарсенное сообщение обработчику Checks::RegisterService' do
        worker.work(message)
        expect(Checks::RegisterService).to have_received(:call).with(parsed_message)
      end

      it 'помечает запись успешно обработанной' do
        worker.work(message)
        expect(RabbitMessage.last).to have_attributes(action: 'pay_register', success: true)
      end

      it 'подтверждает обработку сообщения (ack)' do
        worker.work(message)
        expect(worker).to have_received(:ack!)
      end
    end

    context 'когда action не поддерживается' do
      let(:message) { { action: 'unknown_action', payload: {} }.to_json }

      it 'отклоняет сообщение (reject)' do
        worker.work(message)
        expect(worker).to have_received(:reject!)
      end

      it 'не подтверждает обработку' do
        worker.work(message)
        expect(worker).not_to have_received(:ack!)
      end

      it 'помечает запись как неуспешно обработанную' do
        worker.work(message)
        expect(RabbitMessage.last.success).to be(false)
      end

      it 'не вызывает обработчик регистрации' do
        worker.work(message)
        expect(Checks::RegisterService).not_to have_received(:call)
      end
    end
  end
end
