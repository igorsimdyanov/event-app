# frozen_string_literal: true

RSpec.describe RecognizerListener do
  subject(:worker) { described_class.new }

  # Воркер принимает сообщение методом work_with_params: сведения о доставке
  # дают маршрутный ключ, properties — заголовки трассировки (ADR-0011)
  let(:delivery_info) { instance_double(Bunny::DeliveryInfo, routing_key: 'recognized_result') }
  let(:metadata) { instance_double(Bunny::MessageProperties, headers: nil) }

  let(:parsed_message) do
    { action: 'recognized_result', payload: { file: 'check.jpeg', message: 'распознанный текст' } }
  end
  let(:message) { parsed_message.to_json }

  before do
    allow(worker).to receive(:ack!)
    allow(worker).to receive(:reject!)
    allow(Pays::AnalyseService).to receive(:call)
  end

  describe '#work_with_params' do
    context 'когда action поддерживается' do
      it 'создаёт входящую запись RabbitMessage' do
        expect { worker.work_with_params(message, delivery_info, metadata) }
          .to change { RabbitMessage.income.count }.by(1)
      end

      it 'передаёт распарсенное сообщение обработчику Pays::AnalyseService' do
        worker.work_with_params(message, delivery_info, metadata)
        expect(Pays::AnalyseService).to have_received(:call).with(parsed_message)
      end

      it 'помечает запись успешно обработанной' do
        worker.work_with_params(message, delivery_info, metadata)
        expect(RabbitMessage.last).to have_attributes(action: 'recognized_result', success: true)
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

      it 'не вызывает обработчик анализа платежа' do
        worker.work_with_params(message, delivery_info, metadata)
        expect(Pays::AnalyseService).not_to have_received(:call)
      end
    end
  end
end
