# frozen_string_literal: true

RSpec.describe RabbitMessages::Logging do
  let(:including_class) do
    Class.new do
      include RabbitMessages::Logging
    end
  end
  let(:instance) { including_class.new }

  describe '#initialize_rabbit_message!' do
    let(:data) { { action: 'pay_analyse', payload: { message: 'СУММА=250' } } }

    it 'создаёт запись RabbitMessage' do
      expect { instance.initialize_rabbit_message!(data) }.to change(RabbitMessage, :count).by(1)
    end

    it 'делает созданную запись доступной через #rabbit_message' do
      instance.initialize_rabbit_message!(data)
      expect(instance.rabbit_message).to be_a(RabbitMessage).and be_persisted
    end

    it 'сохраняет action, направление, routing_key и данные' do
      instance.initialize_rabbit_message!(data, RabbitMessage::OUTCOME_MESSAGE, 'pay_register')

      expect(instance.rabbit_message.reload).to have_attributes(
        action: 'pay_analyse',
        direction: 'outcome',
        routing_key: 'pay_register',
        success: true
      )
    end

    it 'по умолчанию помечает сообщение входящим' do
      instance.initialize_rabbit_message!(data)
      expect(instance.rabbit_message.direction).to eq('income')
    end
  end

  describe '#log_error' do
    let(:error) { StandardError.new('boom').tap { |e| e.set_backtrace(%w[line-1 line-2]) } }

    it 'возвращает nil, если ошибка не передана' do
      expect(instance.log_error(nil)).to be_nil
    end

    context 'когда запись RabbitMessage уже создана' do
      before { instance.initialize_rabbit_message!({ action: 'pay_analyse' }) }

      it 'помечает запись неуспешной и сохраняет сообщение об ошибке' do
        instance.log_error(error)

        expect(instance.rabbit_message.reload).to have_attributes(
          success: false,
          error_message: 'boom',
          error_backtrace: "line-1\nline-2"
        )
      end
    end
  end
end
