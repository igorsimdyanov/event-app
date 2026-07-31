# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailManager do
  let(:first_attachment) { instance_double(Mail::Part) }
  let(:second_attachment) { instance_double(Mail::Part) }
  let(:email) { instance_double(Mail::Message, attachments: [first_attachment, second_attachment]) }
  let(:tempfile) { instance_double(Tempfile) }
  let(:md5) { Digest::MD5.hexdigest('content') }

  before do
    allow(Mail).to receive(:defaults)
    allow(Mail).to receive(:find).and_return([email])
    allow(TempfileManager).to receive(:call).and_yield(tempfile, md5)
  end

  it 'настраивает подключение к почтовому ящику' do
    described_class.call { |_file, _md5| }
    expect(Mail).to have_received(:defaults)
  end

  it 'запрашивает у сервера только непрочитанные письма' do
    described_class.call { |_file, _md5| }
    expect(Mail).to have_received(:find).with(hash_including(keys: %w[NOT SEEN]))
  end

  it 'обрабатывает каждое вложение письма через TempfileManager' do
    described_class.call { |_file, _md5| }

    expect(TempfileManager).to have_received(:call).with(first_attachment)
    expect(TempfileManager).to have_received(:call).with(second_attachment)
  end

  it 'пробрасывает пользовательский блок в обработку каждого вложения' do
    collected = []
    described_class.call { |file, hash| collected << [file, hash] }

    expect(collected).to eq([[tempfile, md5], [tempfile, md5]])
  end

  context 'когда непрочитанных писем нет' do
    before { allow(Mail).to receive(:find).and_return([]) }

    it 'не обращается к TempfileManager' do
      described_class.call { |_file, _md5| }
      expect(TempfileManager).not_to have_received(:call)
    end
  end
end
