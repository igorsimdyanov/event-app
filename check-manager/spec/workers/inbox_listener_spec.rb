# frozen_string_literal: true

RSpec.describe InboxListener do
  subject(:worker) { described_class.new }

  # Воркер принимает сообщение методом work_with_params: сведения о доставке
  # дают маршрутный ключ, properties — заголовки трассировки (ADR-0011)
  let(:delivery_info) { instance_double(Bunny::DeliveryInfo, routing_key: 'attachment_registered') }
  let(:metadata) { instance_double(Bunny::MessageProperties, headers: nil) }

  let(:parsed_message) do
    { action: 'attachment_registered', payload: { file: 'check.jpeg', attachment_id: 'a1' } }
  end
  let(:message) { parsed_message.to_json }

  before do
    allow(worker).to receive(:ack!)
    allow(worker).to receive(:reject!)
    allow(worker).to receive(:requeue!)
    allow(Checks::RecognizeService).to receive(:call)
  end

  describe '#work_with_params' do
    context 'когда action поддерживается' do
      it 'создаёт входящую запись RabbitMessage' do
        expect { worker.work_with_params(message, delivery_info, metadata) }
          .to change { RabbitMessage.income.count }.by(1)
      end

      it 'передаёт распарсенное сообщение обработчику Checks::RecognizeService' do
        worker.work_with_params(message, delivery_info, metadata)
        expect(Checks::RecognizeService).to have_received(:call).with(parsed_message)
      end

      it 'помечает запись успешно обработанной' do
        worker.work_with_params(message, delivery_info, metadata)
        expect(RabbitMessage.last).to have_attributes(action: 'attachment_registered', success: true)
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

      it 'не вызывает обработчик распознавания' do
        worker.work_with_params(message, delivery_info, metadata)
        expect(Checks::RecognizeService).not_to have_received(:call)
      end

      it 'помечает запись как неуспешно обработанную' do
        worker.work_with_params(message, delivery_info, metadata)
        expect(RabbitMessage.last.success).to be(false)
      end
    end

    context 'когда обработка прерывается сетевым таймаутом' do
      before { allow(Checks::RecognizeService).to receive(:call).and_raise(Net::ReadTimeout) }

      it 'возвращает сообщение в очередь (requeue)' do
        worker.work_with_params(message, delivery_info, metadata)
        expect(worker).to have_received(:requeue!)
      end

      it 'не подтверждает и не отклоняет сообщение' do
        worker.work_with_params(message, delivery_info, metadata)
        expect(worker).not_to have_received(:ack!)
        expect(worker).not_to have_received(:reject!)
      end
    end

    context 'с реальным сообщением из фикстуры hello.json' do
      let(:message) { Rails.root.join('spec', 'fixtures', 'hello.json').read }

      it 'передаёт обработчику распознавания полезную нагрузку вложения' do
        worker.work_with_params(message, delivery_info, metadata)

        expect(Checks::RecognizeService).to have_received(:call) do |parsed|
          expect(parsed[:action]).to eq('attachment_registered')
          expect(parsed.dig(:payload, :file)).to eq('549c96e1-2db2-44d3-b1ff-c1a2840d61b3.jpg')
          expect(parsed.dig(:payload, :attachment_id)).to eq('0c28688c-0086-4beb-b6d6-8b5bb1d59861')
        end
      end
    end
  end
end
