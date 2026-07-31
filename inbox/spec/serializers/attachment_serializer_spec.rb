# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AttachmentSerializer do
  subject(:message) { JSON.parse(described_class.new(attachment).serialize) }

  let(:attachment) { create(:attachment) }

  describe 'заголовок сообщения' do
    it 'указывает тип события' do
      expect(message['action']).to eq('attachment_registered')
    end

    it 'указывает routing key из настроек' do
      expect(message['routing_key']).to eq(Settings.rabbitmq.routing_key)
    end

    it 'проставляет время формирования сообщения как unix-таймстамп' do
      expect(message['created_at']).to be_a(Integer)
    end
  end

  describe 'полезная нагрузка' do
    subject(:payload) { message['payload'] }

    it 'содержит идентификатор вложения' do
      expect(payload['attachment_id']).to eq(attachment.id)
    end

    it 'содержит имя файла' do
      expect(payload['file']).to eq(attachment.file.identifier)
    end

    it 'содержит полный путь к файлу в хранилище' do
      expect(payload['full_path']).to eq(attachment.file.path)
    end

    it 'содержит хэш-сумму md5' do
      expect(payload['md5']).to eq(attachment.md5)
    end

    it 'содержит время создания вложения как unix-таймстамп' do
      expect(payload['created_at']).to eq(attachment.created_at.utc.to_i)
    end
  end
end
