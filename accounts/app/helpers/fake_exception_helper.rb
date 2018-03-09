module FakeExceptionHelper

  def raise_fake_exception(type)
    case type
    when 'security_transgression'
      raise SecurityTransgression
    when 'record_not_found'
      raise ActiveRecord::RecordNotFound
    when 'routing_error'
      raise ActionController::RoutingError.new "/blah/blah/blah"
    when 'unknown_controller'
      raise ActionController::UnknownController
    when 'unknown_action'
      raise ActionController::UnknownAction
    when 'missing_template'
      raise ActionView::MissingTemplate.new(['a', 'b'], 'path', ['pre1', 'pre2'], 'partial', 'details')
    when 'not_yet_implemented'
      raise NotYetImplemented
    when 'illegal_argument'
      raise IllegalArgument
    end
  end

end