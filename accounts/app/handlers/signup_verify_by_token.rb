class SignupVerifyByToken

  lev_handler

  uses_routine ConfirmByCode,
               translations: { outputs: { map: { contact_info: :signup_state } },
                               inputs: { type: :verbatim } }
  uses_routine SignupTrustedStudent, translations: { outputs: { type: :verbatim } }

  protected

  def authorized?
    true
  end

  def handle
    run(ConfirmByCode, params[:code])

    if outputs[:signup_state].try(:trusted_student?)
      run(SignupTrustedStudent, outputs[:signup_state])
      options[:session].sign_in!(outputs.user)
    end
  end

end
