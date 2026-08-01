# frozen_string_literal: true

RSpec.describe TempfileManager do
  it 'создаёт временный файл с переданным содержимым и отдаёт его путь в блок' do
    written = nil
    described_class.call('image-bytes', 'check.png') do |path|
      written = File.read(path)
      'ignored'
    end

    expect(written).to eq('image-bytes')
  end

  it 'возвращает результат выполнения блока' do
    result = described_class.call('image-bytes', 'check.png') { |_path| 'распознанный текст' }

    expect(result).to eq('распознанный текст')
  end

  it 'сохраняет исходное имя и расширение временного файла' do
    basename = nil
    described_class.call('image-bytes', 'dir/check.png') { |path| basename = File.basename(path) }

    expect(basename).to match(/\Acheck.*\.png\z/)
  end

  it 'удаляет временный файл после выполнения блока' do
    path = nil
    described_class.call('image-bytes', 'check.png') { |p| path = p }

    expect(File.exist?(path)).to be(false)
  end
end
