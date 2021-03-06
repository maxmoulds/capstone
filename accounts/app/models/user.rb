class User < ActiveRecord::Base

  USERNAME_VALID_REGEX = /\A[A-Za-z\d_]+\z/
  USERNAME_MIN_LENGTH = 3
  USERNAME_MAX_LENGTH = 50
  VALID_STATES = [
    'temp', # deprecated but still could exist for old accounts
    'new_social',
    'unclaimed',
    'needs_profile',
    'activated'
  ]

  has_one :identity, dependent: :destroy, inverse_of: :user

  has_many :authentications, dependent: :destroy, inverse_of: :user
  has_many :application_users, dependent: :destroy, inverse_of: :user
  has_many :applications, through: :application_users
  has_many :contact_infos, dependent: :destroy, inverse_of: :user
  has_many :email_addresses, inverse_of: :user

  has_many :message_recipients, inverse_of: :user, dependent: :destroy
  has_many :received_messages, through: :message_recipients, source: :message
  has_many :sent_messages, class_name: 'Message'
  has_many :external_uuids, class_name: 'UserExternalUuid', dependent: :destroy
  has_many :group_owners, dependent: :destroy, inverse_of: :user
  has_many :owned_groups, through: :group_owners, source: :group

  has_many :group_members, dependent: :destroy, inverse_of: :user
  has_many :member_groups, through: :group_members, source: :group

  has_many :oauth_applications, through: :member_groups

  has_many :security_logs

  enum faculty_status: [:no_faculty_info, :pending_faculty, :confirmed_faculty, :rejected_faculty]
  enum role: [:unknown_role, :student, :instructor, :administrator, :librarian, :designer, :other]

  DEFAULT_FACULTY_STATUS = :no_faculty_info
  validates :faculty_status, presence: true

  validates :role, presence: true

  before_validation :strip_fields

  validates :username, length: { minimum: USERNAME_MIN_LENGTH,
                                 maximum: USERNAME_MAX_LENGTH,
                                 allow_blank: true },
                       format: { with: USERNAME_VALID_REGEX,
                                 allow_blank: true }

  validates :username, uniqueness: { case_sensitive: false, allow_nil: true },
                       if: :username_changed?

  validates :state, inclusion: { in: VALID_STATES,
                                 message: "must be one of #{VALID_STATES.join(',')}" }

  validate :ensure_names_continue_to_be_present

  validates :login_token, uniqueness: { allow_nil: true }

  validates :uuid, :support_identifier, presence: true, uniqueness: true

  delegate_to_routine :destroy

  attr_accessible :title, :first_name, :last_name, :suffix, :username

  attr_readonly :uuid, :support_identifier

  before_validation :generate_uuid, :generate_support_identifier, on: :create

  before_create :make_first_user_an_admin

  before_save :add_unread_update

  def self.username_is_valid?(username)
    user = User.new(username: username)
    user.valid?
    user.errors[:username].none?
  end

  def self.create_random_username(base:, num_digits_in_suffix:)
    "#{base}#{rand(10**num_digits_in_suffix).to_s.rjust(num_digits_in_suffix,'0')}"
  end

  def is_test?
    !!is_test
  end

  def is_anonymous?
    false
  end

  def is_human?
    true
  end

  def is_application?
    false
  end

  # State helpers.
  #
  # A User model begins life in the "temp" state, and can then be claimed by another user
  # who originated from an OAuth login. Upon it being claimed it will be removed and it's
  # data merged with the claimant.
  #
  # A User can also be created by a one of the consumer applications as a stand-in
  # for a person who has not yet (or may never) created an account.  In this case
  # the User model will be in the "unclaimed" state.  When the User does signup, they
  # can claim the account and recieve all the permissions and tasks
  # that were assigned to it in the interm.
  #
  # Once a User model is cleared for use, the state is set to "activated"
  def is_activated?
    'activated' == state
  end

  def is_temp?
    'temp' == state
  end

  def is_unclaimed?
    'unclaimed' == state
  end

  def is_new_social?
    'new_social' == state
  end

  def is_needs_profile?
    'needs_profile' == state
  end

  def name
    full_name.present? ? full_name : username
  end

  def full_name
    guess = "#{title} #{first_name} #{last_name} #{suffix}".gsub(/\s+/,' ').strip
    guess.blank? ? nil : guess
  end

  def full_name=(name)
    names = name.strip.split(/\s+/)
    self.first_name = names.first
    self.last_name = (names.length > 1 ? names[1..-1] : ['']).join(' ')
  end

  def guessed_first_name
    full_name.present? ? full_name.split("\s")[0] : nil
  end

  def guessed_last_name
    full_name.present? ? full_name.split("\s").drop(1).join(' ') : nil
  end

  def casual_name # TODO are we ok now that username not required?
    first_name.present? ? first_name : username
  end

  def standard_name # TODO needs spec
    formal_name.present? ? formal_name : casual_name
  end

  def formal_name # TODO needs spec
    "#{title} #{last_name} #{suffix}".gsub(/\s+/,' ').strip if title.present? && last_name.present?
  end

  def add_unread_update
    # Returns false if the update fails (aborting the save transaction)
    AddUnreadUpdateForUser.call(self).errors.none?
  end

  def has_emails_but_none_verified?
    email_addresses.any? && email_addresses.none?(&:verified)
  end

  def created_from_trusted_data?
    trusted_signup_data.present?
  end
  ##########################
  # Access Control Helpers #
  ##########################

  def can_read?(resource)
    resource.can_be_read_by?(self)
  end

  def can_create?(resource)
    resource.can_be_created_by?(self)
  end

  def can_update?(resource)
    resource.can_be_updated_by?(self)
  end

  def can_destroy?(resource)
    resource.can_be_destroyed_by?(self)
  end

  def can_sort?(resource)
    resource.can_be_sorted_by?(self)
  end

  # Login token

  def refresh_login_token(expiration_period: nil)
    if login_token.blank? || login_token_expired? || expiration_period.try(:<,0)
      self.login_token = SecureRandom.hex(16)
    end

    self.login_token_expires_at = expiration_period.nil? ? nil : DateTime.now + expiration_period
  end

  def login_token_expired?
    !login_token_expires_at.nil? && login_token_expires_at <= DateTime.now
  end

  def self.known_roles
    roles.except("unknown_role").keys
  end

  def self.non_student_known_roles
    known_roles - ["student"]
  end

  def guessed_preferred_confirmed_email
    # A heuristic for guessing the user's preferred confirmed email.  Assumes that
    # emails that were manually entered are more preferred than those that were
    # added via a social login. Manually-entered emails trigger confirmation emails,
    # so those emails have the confirmation sent at timestamp.

    if email_addresses.loaded? || contact_infos.loaded?
      emails = email_addresses.loaded? ? email_addresses : contact_infos.select(&:email?)
      verified_emails = emails.select(&:verified?)
      manual_emails = verified_emails.reject { |email| email.confirmation_sent_at.nil? }
      manual_emails.any? ? manual_emails.max_by(&:created_at) : verified_emails.min_by(&:created_at)
    else
      email_addresses.verified.order(
        <<-SQL.strip_heredoc
          CASE WHEN "confirmation_sent_at" IS NULL THEN '-infinity' ELSE "created_at" END DESC,
          "created_at" ASC
        SQL
      ).first
    end.try!(:value)
  end

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def generate_support_identifier(length: 4)
    self.support_identifier ||= "cs_#{SecureRandom.hex(length)}"
  end

  protected

  def make_first_user_an_admin
    return if Rails.env.production? || Rails.env.test?
    self.is_administrator = true if User.count == 0
  end

  def strip_fields
    self.title.try(:strip!)
    self.first_name.try(:strip!)
    self.last_name.try(:strip!)
    self.suffix.try(:strip!)
    self.username.try(:strip!)
    self.username = nil if self.username.blank?
    self.self_reported_school.try(:strip!)
    true
  end

  # there are existing users without names
  # allow them to continue to function, but require a name to exist once it's set
  def ensure_names_continue_to_be_present
    return true if is_needs_profile?

    %w{first_name last_name}.each do |attr|
      change = changes[attr]

      next if change.nil? # no change, so no problem

      was = change[0]
      is = change[1]

      errors.add(attr.to_sym, :blank) if !was.blank? && is.blank?
    end
  end

end
