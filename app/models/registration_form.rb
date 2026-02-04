class RegistrationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Account attributes
  attribute :account_name, :string
  attribute :plan_tier, :string

  # Agency attributes
  attribute :agency_name, :string

  # User attributes
  attribute :user_first_name, :string
  attribute :user_last_name, :string
  attribute :user_email, :string
  attribute :user_password, :string

  # Store created records
  attr_reader :account, :agency, :user

  # Validations
  validates :account_name, presence: true
  validates :plan_tier, presence: true, inclusion: { in: Plan.all.map(&:to_s) }
  validates :agency_name, presence: true
  validates :user_first_name, presence: true
  validates :user_last_name, presence: true
  validates :user_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :user_password, presence: true, length: { minimum: 8 }

  validate :user_email_uniqueness

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

  def create_account!
    @account = Account.create!(
      name: account_name,
      plan_tier: plan_tier
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
      first_name: user_first_name,
      last_name: user_last_name,
      email: user_email,
      password: user_password,
      password_confirmation: user_password,
      role: "owner"
    )
  end

  def user_email_uniqueness
    if user_email.present? && User.exists?(email: user_email)
      errors.add(:user_email, "has already been taken")
    end
  end
end
