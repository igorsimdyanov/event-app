class Checks::BuildMessageService
  include Callable
  extend Dry::Initializer

  option :message
  option :routing_key
  option :reply_to, optional: true

  def call
    {
      action: routing_key,
      payload: {
        file: message.dig(:payload, :file),
        full_path: message.dig(:payload, :full_path),
        attachment_id: message.dig(:payload, :attachment_id),
        created_at: message.dig(:payload, :created_at)
      },
      created_at: Time.now.utc.to_i,
      routing_key: routing_key,
      reply_to: reply_to
    }
  end
end
