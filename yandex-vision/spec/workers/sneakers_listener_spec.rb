# frozen_string_literal: true

RSpec.describe SneakersListener do
  subject(:worker) { described_class.new }

  let(:parsed_message) do
    { action: 'recognize', reply_to: 'recognized_result', payload: { full_path: 'attachment/2026-07-31/check.png' } }
  end
  let(:message) { parsed_message.to_json }

  before do
    allow(worker).to receive(:ack!)
    allow(worker).to receive(:reject!)
    allow(Checks::RecognizeService).to receive(:call)
  end

  describe '#work' do
    context 'когда action поддерживается' do
      it 'передаёт распарсенное сообщение обработчику Checks::RecognizeService' do
        worker.work(message)
        expect(Checks::RecognizeService).to have_received(:call).with(parsed_message)
      end

      it 'подтверждает обработку сообщения (ack)' do
        worker.work(message)
        expect(worker).to have_received(:ack!)
      end

      it 'не отклоняет сообщение' do
        worker.work(message)
        expect(worker).not_to have_received(:reject!)
      end
    end

    context 'когда action не поддерживается' do
      let(:message) { { action: 'unknown_action' }.to_json }

      it 'отклоняет сообщение (reject)' do
        worker.work(message)
        expect(worker).to have_received(:reject!)
      end

      it 'не подтверждает обработку' do
        worker.work(message)
        expect(worker).not_to have_received(:ack!)
      end

      it 'не вызывает обработчик распознавания' do
        worker.work(message)
        expect(Checks::RecognizeService).not_to have_received(:call)
      end
    end
  end
end
