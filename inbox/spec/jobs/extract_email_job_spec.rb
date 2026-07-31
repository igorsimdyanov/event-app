# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExtractEmailJob, type: :job do
  subject(:perform) { described_class.perform_now }

  let(:md5) { Digest::MD5.hexdigest('email-attachment') }
  let(:tmpfile) { File.open(Rails.root.join('spec/fixtures/check001.jpeg')) }

  after { tmpfile.close unless tmpfile.closed? }

  context 'когда MailManager отдаёт вложение из письма' do
    before { allow(MailManager).to receive(:call).and_yield(tmpfile, md5) }

    it 'делегирует чтение почтового ящика MailManager' do
      perform
      expect(MailManager).to have_received(:call)
    end

    it 'создаёт запись вложения' do
      expect { perform }.to change(Attachment, :count).by(1)
    end

    it 'сохраняет переданную хэш-сумму md5' do
      perform
      expect(Attachment.last.md5).to eq(md5)
    end

    it 'прикрепляет к вложению переданный файл' do
      perform
      expect(Attachment.last.file.identifier).to be_present
    end
  end

  context 'когда вложение с такой хэш-суммой уже зарегистрировано' do
    before do
      create(:attachment, md5: md5)
      allow(MailManager).to receive(:call).and_yield(tmpfile, md5)
    end

    it 'не создаёт дубль вложения' do
      expect { perform }.not_to change(Attachment, :count)
    end
  end

  context 'когда новых непрочитанных писем нет' do
    before { allow(MailManager).to receive(:call) }

    it 'не создаёт вложений' do
      expect { perform }.not_to change(Attachment, :count)
    end
  end
end
