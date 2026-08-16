class Checks::ApproveService
  include Callable
  extend Dry::Initializer

  param :id

  def call
    check = Check.find(id)
    check.update!(approved: true)

    next_message = Checks::BuildMessageService.call(
                     check: check,
                     routing_key: 'pay_register')

    RabbitMessages::Send.call(next_message)
  end
end
