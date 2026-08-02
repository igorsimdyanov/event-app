# Хронология событий чека: порядковый номер шага и задержка от предыдущего события
class Events::TimelineService
  include Callable
  extend Dry::Initializer

  param :events

  def call
    self
  end

  def position_of(event)
    positions[event.id]
  end

  def delay_of(event)
    delays[event.id]
  end

  private

  def positions
    @positions ||= events.each_with_index.to_h { |event, index| [ event.id, index + 1 ] }
  end

  def delays
    @delays ||= events.each_cons(2).filter_map { |previous, current|
      next unless previous.occurred_at && current.occurred_at

      [ current.id, current.occurred_at - previous.occurred_at ]
    }.to_h
  end
end
