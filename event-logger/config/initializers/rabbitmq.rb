class RabbitConnectionManager
  # HINT: Thread-safe instance/class variables
  thread_mattr_accessor :active_connection, :active_channel

  class << self
    def channel
      reconnect unless connected? && active_channel&.open?
      active_channel
    end

    def close!
      active_channel&.close
      active_connection&.close
    end

    def connection_settings
      @connection_settings ||= Settings.rabbitmq.to_hash
    end

    private

    def establish_connection
      self.active_connection = Bunny.new(connection_settings)
      active_connection.start
      self.active_channel = active_connection.create_channel
    end

    def reconnect
      close!
      establish_connection
    end

    def connected?
      active_connection&.connected?
    end
  end
end
