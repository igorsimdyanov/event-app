# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TempfileManager do
  let(:content) { File.binread(Rails.root.join('spec/fixtures/check001.jpeg')) }
  let(:body) { instance_double(Mail::Body, decoded: content) }
  let(:attachment) { instance_double(Mail::Part, filename: 'check001.jpeg', body: body) }

  it 'вызывает блок с временным файлом и md5-хэшем содержимого' do
    expect { |probe| described_class.call(attachment, &probe) }
      .to yield_with_args(Tempfile, Digest::MD5.hexdigest(content))
  end

  it 'записывает во временный файл декодированное содержимое вложения' do
    written = nil
    described_class.call(attachment) { |tempfile, _md5| written = tempfile.read }

    expect(written).to eq(content)
  end

  it 'сохраняет исходное имя и расширение временного файла' do
    basename = nil
    described_class.call(attachment) { |tempfile, _md5| basename = File.basename(tempfile.path) }

    expect(basename).to match(/\Acheck001.*\.jpeg\z/)
  end

  it 'удаляет временный файл после выполнения блока' do
    path = nil
    described_class.call(attachment) { |tempfile, _md5| path = tempfile.path }

    expect(File.exist?(path)).to be(false)
  end
end
