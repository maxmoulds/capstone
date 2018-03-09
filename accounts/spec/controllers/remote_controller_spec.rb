require 'rails_helper'

describe RemoteController, type: :controller do

  let(:valid_iframe_origins) { Rails.application.secrets[:valid_iframe_origins] }
  let(:user)                 { FactoryGirl.create :user, :terms_agreed }

  context 'loading iframe' do
    render_views

    it 'throws when parent is not present or invalid' do
      get(:iframe)
      expect(response).to have_http_status :forbidden
      get(:iframe, parent: 'foo')
      expect(response).to have_http_status :forbidden
    end

    it 'loads and sets parent as context' do
      origin = valid_iframe_origins.last
      expect {
        get(:iframe, parent: origin)
      }.to_not raise_error()
      expect(response.body).to match("parentLocation: '#{origin}'")
    end

  end

  context 'logging out via external site' do
    render_views

    it 'notifies parent on logout' do
      url = valid_iframe_origins.last
      get :notify_logout, parent: url
      expect(response.body).to match(/window.parent.postMessage.*logoutComplete/)
    end

  end

end
