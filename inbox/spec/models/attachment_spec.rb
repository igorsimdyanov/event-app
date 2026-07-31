# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Attachment, type: :model do
  subject(:attachment) { build(:attachment) }

  describe 'валидации' do
    it { is_expected.to validate_uniqueness_of(:md5) }

    it 'является валидным с фабричными атрибутами' do
      expect(attachment).to be_valid
    end

    context 'когда вложение с таким же md5 уже существует' do
      let(:md5) { Digest::MD5.hexdigest('one-and-only') }

      before { create(:attachment, md5: md5) }

      it 'не позволяет создать дубль по хэш-сумме' do
        duplicate = build(:attachment, md5: md5)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:md5]).to be_present
      end
    end
  end

  describe '.not_sent' do
    it 'возвращает только неотправленные вложения' do
      pending_attachment = create(:attachment)
      create(:attachment, :sent)

      expect(Attachment.not_sent).to contain_exactly(pending_attachment)
    end

    it 'по умолчанию новое вложение считается неотправленным' do
      expect(create(:attachment).sent).to be(false)
    end
  end

  describe 'загрузчик файла' do
    it 'монтирует AttachmentUploader на поле file' do
      expect(attachment.file).to be_a(AttachmentUploader)
    end

    it 'сохраняет имя файла в идентификаторе с расширением' do
      expect(create(:attachment).file.identifier).to match(/\A[\h-]+\.jpeg\z/)
    end
  end
end
