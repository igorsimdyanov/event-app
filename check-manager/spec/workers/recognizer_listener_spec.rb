# frozen_string_literal: true

RSpec.describe RecognizerListener do
  subject(:worker) { described_class.new }

  let(:parsed_message) do
    { action: 'recognized_result', payload: { file: 'check.jpeg', message: 'распознанный текст' } }
  end
  let(:message) { parsed_message.to_json }

  before do
    allow(worker).to receive(:ack!)
    allow(worker).to receive(:reject!)
    allow(Pays::AnalyseService).to receive(:call)
  end

  describe '#work' do
    context 'когда action поддерживается' do
      it 'создаёт входящую запись RabbitMessage' do
        expect { worker.work(message) }.to change { RabbitMessage.income.count }.by(1)
      end

      it 'передаёт распарсенное сообщение обработчику Pays::AnalyseService' do
        worker.work(message)
        expect(Pays::AnalyseService).to have_received(:call).with(parsed_message)
      end

      it 'помечает запись успешно обработанной' do
        worker.work(message)
        expect(RabbitMessage.last).to have_attributes(action: 'recognized_result', success: true)
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

      it 'не вызывает обработчик анализа платежа' do
        worker.work(message)
        expect(Pays::AnalyseService).not_to have_received(:call)
      end
    end
  end
end
