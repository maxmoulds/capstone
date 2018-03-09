class AddEmailToUser

  lev_routine express_output: :email

  uses_routine SendContactInfoConfirmation

  protected

  def exec(email_address_text, user, options={})
    # If no email address, nothing to do
    return if email_address_text.blank?

    # If the email address already exists and is attached to the user, nothing to do
    email_address = user.email_addresses.find_by(value: email_address_text)
    return if email_address.try!(:verified)

    # If it is a brand new email address, make it
    if email_address.nil?
      email_address = EmailAddress.new(value: email_address_text)
      email_address.user = user
    end

    # This is either a new email address (unverified) or an existing email address
    # that is unverified, so verified should be false unless already verified
    email_address.verified = options[:already_verified] || false

    email_address.save
    transfer_errors_from(email_address, { scope: :email_address }, true)

    # The confirmation info won't be sent if already verified
    run(SendContactInfoConfirmation, contact_info: email_address)

    outputs.email = email_address

    # Ensure we get updated contact_infos if we try to use them
    user.contact_infos.reset
    user.email_addresses.reset
  end
end
