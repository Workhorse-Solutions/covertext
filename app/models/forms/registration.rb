class Forms::Registration
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Stripe custom field keys (must match controller)
  FIRST_NAME_FIELD = "first_name"
  LAST_NAME_FIELD = "last_name"

  # Account attributes (extracted from Stripe)
  attribute :account_name, :string

  # Agency attributes (extracted from Stripe)
  attribute :agency_name, :string

  # User attributes (extracted from Stripe + form)
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :email, :string
  attribute :password, :string
  attribute :password_confirmation, :string

  # Stripe checkout session (not persisted)
  attr_accessor :checkout_session

  # Store created records
  attr_reader :account, :agency, :user

  # Custom initializer to accept Stripe data or individual attributes
  def initialize(checkout_session: nil, password_params: {}, **attrs)
    if checkout_session
      @checkout_session = checkout_session

      # Extract customer data from Stripe
      customer = Stripe::Customer.retrieve(checkout_session.customer)

      # Extract custom fields
      first_name = checkout_session.custom_fields&.find { |f| f.key == FIRST_NAME_FIELD }&.text&.value
      last_name = checkout_session.custom_fields&.find { |f| f.key == LAST_NAME_FIELD }&.text&.value

      # Initialize with data from Stripe + password from form
      super(
        account_name: checkout_session.metadata.account_name,
        agency_name: checkout_session.metadata.agency_name,
        first_name: first_name.presence || "User",
        last_name: last_name,
        email: customer.email,
        password: password_params[:password],
        password_confirmation: password_params[:password_confirmation]
      )
    else
      # Allow creating without checkout_session for display purposes (success view)
      @checkout_session = nil
      super(**attrs)
    end
  end

  # Validations
  validates :account_name, presence: true
  validates :agency_name, presence: true
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 8 }, if: :password_required?
  validates :password_confirmation, presence: true, if: :password_required?
  validate :passwords_match, if: :password_required?
  validate :email_uniqueness

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      create_account!
      create_agency!
      create_user!
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    # Copy errors from nested models to form object
    e.record.errors.each do |error|
      errors.add(error.attribute, error.message)
    end
    false
  end

  private

  def plan_tier
    return nil unless checkout_session
    tier = checkout_session.metadata.plan_tier&.to_sym
    Plan.valid?(tier) ? tier.to_s : Plan.default.to_s
  end

  def create_account!
    @account = Account.create!(
      name: account_name,
      plan_tier: plan_tier,
      stripe_customer_id: checkout_session.customer,
      stripe_subscription_id: checkout_session.subscription,
      subscription_status: "active"
    )
  end

  def create_agency!
    @agency = @account.agencies.create!(
      name: agency_name,
      active: true,
      live_enabled: false
    )
  end

  def create_user!
    @user = @account.users.create!(
      first_name: first_name,
      last_name: last_name,
      email: email,
      password: password,
      password_confirmation: password_confirmation,
      role: "owner"
    )
  end

  def passwords_match
    if password.present? && password != password_confirmation
      errors.add(:password_confirmation, "doesn't match password")
    end
  end

  def email_uniqueness
    if email.present? && User.exists?(email: email)
      errors.add(:email, "has already been taken")
    end
  end

  def password_required?
    # Password is required when saving (password will be present from form)
    # Not required when just displaying (password will be nil)
    password.present? || password_confirmation.present?
  end
end
