# coding: utf-8
require 'rails_helper'

describe SessionsCreate, type: :handler do

  let(:user_state) { MockUserState.new }
  let(:login_providers) { nil }
  let(:signup_state) { nil }

  context "logging in" do
    context "no user linked to oauth response" do
      let(:login_providers) { { 'does_not' => {'uid' => 'matter'} } }

      it "returns mismatched_authentication status and does not log in" do
        result = handle(
          request: MockOmniauthRequest.new('facebook', 'blah', {}) # fabricated so no user will be linked
        )
        expect(result.outputs.status).to eq :mismatched_authentication
        expect(user_state).not_to be_signed_in
      end
    end

    context "oauth response doesn't match log in username/email" do
      let(:authentication) { FactoryGirl.create(:authentication, provider: 'google_oauth2') }
      let(:login_providers) { { 'google_oauth2' => {'uid' => 'some_other_uid'} } }

      it "returns mismatched_authentication status and does not log in" do
        result = handle(
          request: MockOmniauthRequest.new(authentication.provider, authentication.uid, {})
        )
        expect(result.outputs.status).to eq :mismatched_authentication
        expect(user_state).not_to be_signed_in
      end
    end

    context "happy path" do
      let(:authentication) { FactoryGirl.create(:authentication, provider: 'google_oauth2') }
      let(:login_providers) { { 'google_oauth2' => {'uid' => authentication.uid} } }

      it "returns returning_user status and logs in" do
        result = handle(
          request: MockOmniauthRequest.new(authentication.provider, authentication.uid, {})
        )
        expect(result.outputs.status).to eq :returning_user
        expect(user_state).to be_signed_in
      end

      it "as a side effect updates the login_hint for google oauth" do
        result = handle(
          request: MockOmniauthRequest.new(authentication.provider,
                                           authentication.uid,
                                           {email: "bob@bob.com"})
        )
        expect(result.outputs.authentication.login_hint).to eq "bob@bob.com"
      end
    end
  end

  context "signing up" do
    context "oauth response already directly linked to a user" do
      let(:authentication) { FactoryGirl.create(:authentication, provider: 'google_oauth2') }
      let(:signup_state) {
        FactoryGirl.create(:signup_state, :verified, contact_info_value: "bob@bob.com")
      }
      it "returns existing_user_signed_up_again status and transfers email" do
        result = handle(request: MockOmniauthRequest.new(authentication.provider, authentication.uid, {}))
        expect(result.outputs.status).to eq :existing_user_signed_up_again
        expect(authentication.user.contact_infos.verified.map(&:value)).to include "bob@bob.com"
      end
    end

    context "oauth response already linked to user by email address" do
      let(:other_user_email) { FactoryGirl.create(:email_address, verified: true)}
      let(:signup_state) {
        FactoryGirl.create(:signup_state, :verified, contact_info_value: "bob@bob.com")
      }

      it "returns existing_user_signed_up_again status and transfers auth" do
        expect {
          result = handle(request: MockOmniauthRequest.new("facebook",
                                                           "some_uid",
                                                           {email: other_user_email.value}))
          expect(result.outputs.status).to eq :existing_user_signed_up_again
          expect(SignupState.count).to eq 0
        }.to change{other_user_email.user.authentications.count}.by 1
      end
    end

    context "normal password sign up" do
      let(:identity) { FactoryGirl.create :identity }
      let(:signup_state) {
        FactoryGirl.create(:signup_state, :verified, contact_info_value: "bob@bob.com")
      }

      it "adds authentication, logs in user, returns new_password_user" do
        expect(identity.user.authentications).to be_empty
        result = handle(request: MockOmniauthRequest.new("identity", identity.uid, {}))
        expect(result.outputs.status).to eq :new_password_user
        user = identity.user
        expect(user.authentications).not_to be_empty
        expect(user_state).to be_signed_in
        expect(user.contact_infos.size).to eq 1
        expect(user.contact_infos.first.value).to eq "bob@bob.com"
        expect(user.contact_infos.first).to be_verified
        expect(signup_state).to be_destroyed
      end
    end

    context "normal social sign up" do
      let(:signup_state) {
        FactoryGirl.create(:signup_state, :verified, contact_info_value: "bob@bob.com")
      }

      it "adds authentication, logs in user, returns new_social_user" do
        result = handle(request: MockOmniauthRequest.new("facebook", "zuckerberg", {}))
        expect(result.outputs.status).to eq :new_social_user
        expect(user_state).to be_signed_in
        user = user_state.current_user
        authentication = user.authentications(true).first
        expect(authentication.provider).to eq "facebook"
        expect(authentication.uid).to eq "zuckerberg"
        expect(user.contact_infos.size).to eq 1
        expect(user.contact_infos.first.value).to eq "bob@bob.com"
        expect(user.contact_infos.first).to be_verified
        expect(signup_state).to be_destroyed
      end
    end
  end

  context "logged in" do
    let(:current_user) { FactoryGirl.create :user }
    before(:each) { user_state.sign_in!(current_user) }

    context "authentication already on current user" do
      before {
        FactoryGirl.create(:authentication, provider: "facebook", uid: "blahuid", user: current_user)
      }

      it "returns :no_action" do
        result = handle(request: MockOmniauthRequest.new("facebook", "blahuid", {}))
        expect(result.outputs.status).to eq :no_action
      end
    end

    context "authentication is for a different user" do
      before {
        FactoryGirl.create(:authentication, provider: "facebook",
                                            uid: "blahuid",
                                            user: FactoryGirl.create(:user))
      }

      it "returns :authentication_taken" do
        result = handle(request: MockOmniauthRequest.new("facebook", "blahuid", {}))
        expect(result.outputs.status).to eq :authentication_taken
      end
    end

    context "authentication provider already on current user" do
      before {
        FactoryGirl.create(:authentication, provider: "google_oauth2",
                                            uid: "uid_one",
                                            user: current_user)
      }

      it "returns :same_provider" do
        result = handle(request: MockOmniauthRequest.new("google_oauth2", "uid_two", {}))
        expect(result.outputs.status).to eq :same_provider
      end
    end

    context "user hasn't signed in recently enough to complete action" do
      before(:each) {
        SecurityLog.create! user: current_user, remote_ip: '127.0.0.1',
                            event_type: :sign_in_successful, event_data: {}
        Timecop.freeze(Time.now + RequireRecentSignin::REAUTHENTICATE_AFTER)
      }

      it "returns :new_signin_required" do
        result = handle(request: MockOmniauthRequest.new("google_oauth2", "uid", {}))
        expect(result.outputs.status).to eq :new_signin_required
      end
    end

    context "happy path where authentication is added" do
      before(:each) {
        SecurityLog.create! user: current_user, remote_ip: '127.0.0.1',
                            event_type: :sign_in_successful, event_data: {}
      }

      it "add the authentication, adds the auth email, returns :authentication_added" do
        result = handle(request: MockOmniauthRequest.new("google_oauth2", "uid", {email: "joe@joe.com"}))
        expect(result.outputs.status).to eq :authentication_added
        authentication = current_user.authentications(true).first
        expect(authentication.provider).to eq "google_oauth2"
        expect(authentication.uid).to eq "uid"
        expect(current_user.contact_infos.verified.map(&:value)).to contain_exactly("joe@joe.com")
      end
    end
  end

  context 'user_most_recently_used' do

    it 'returns nil when no users' do
      expect(user_most_recently_used([])).to be_nil
    end

    it 'returns the user when there is only one' do
      user = Object.new
      expect(user_most_recently_used([user])).to eq user
    end

    context "multiple users" do
      before(:each) {
        @user1 = FactoryGirl.create :user, created_at: 1.year.ago
        @user2 = FactoryGirl.create :user, created_at: 1.year.ago

        @user1.update_attribute(:updated_at, 1.month.ago)
        @user2.update_attribute(:updated_at, 1.year.ago)

        @user3 = FactoryGirl.create :user
        Timecop.freeze(2.months.ago) do
          SecurityLog.create! user: @user3, remote_ip: '127.0.0.1',
                              event_type: :sign_in_successful, event_data: {}
        end

        @user4 = FactoryGirl.create :user, created_at: 2.years.ago, updated_at: 2.years.ago
        Timecop.freeze(1.day.ago) do
          SecurityLog.create! user: @user4, remote_ip: '127.0.0.1',
                              event_type: :sign_in_successful, event_data: {}
        end
      }


      it 'favors later updated_at' do
        expect(user_most_recently_used([@user1, @user2])).to eq @user1
      end

      it 'favors later created_at when updated_at equal' do
        @user2.updated_at = @user1.updated_at
        expect(user_most_recently_used([@user1, @user2])).to eq @user2
      end

      it 'favors log in over no log in' do
        expect(user_most_recently_used([@user4, @user1])).to eq @user4
      end

      it 'favors recent logins' do
        expect(user_most_recently_used([@user4, @user3])).to eq @user4
      end
    end
  end

  def handle(**args)
    described_class.handle(user_state: user_state,
                           login_providers: login_providers,
                           signup_state: signup_state,
                           **args)
  end

  def user_most_recently_used(users)
    described_class.new.send(:user_most_recently_used, users)
  end

end
