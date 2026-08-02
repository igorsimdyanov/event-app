# frozen_string_literal: true

RSpec.describe Events::TimelineService do
  let(:receipt) { create(:receipt) }
  let(:first) { create(:event, receipt: receipt, occurred_at: Time.zone.at(100)) }
  let(:second) { create(:event, receipt: receipt, occurred_at: Time.zone.at(130)) }
  let(:timeline) { described_class.call([ first, second ]) }

  it 'нумерует шаги обработки чека' do
    expect(timeline.position_of(second)).to eq(2)
  end

  it 'считает задержку от предыдущего события' do
    expect(timeline.delay_of(second)).to eq(30)
  end

  it 'не считает задержку для первого события' do
    expect(timeline.delay_of(first)).to be_nil
  end

  it 'обходится без задержки, если время события неизвестно' do
    undated = create(:event, receipt: receipt, occurred_at: nil)

    expect(described_class.call([ first, undated ]).delay_of(undated)).to be_nil
  end
end
