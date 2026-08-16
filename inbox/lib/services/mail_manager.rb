# frozen_string_literal: true

class MailManager
  def self.call(&)
    new.call(&)
  end

  def call(&)
    connect
    attachments(emails, &)
  end

  private

  def connect
    Mail.defaults do
      retriever_method :imap,
        address: Settings.imap.server,
        port: Settings.imap.port,
        user_name: Settings.imap.email,
        password: Settings.imap.password,
        enable_ssl: true
    end
  end

  def emails
    Mail.find(keys: %w[NOT SEEN])
  end

  def attachments(emails, &)
    emails.each do |email|
      email.attachments.map do |attachment|
        TempfileManager.call(attachment, &)
      end
    end
  end
end
