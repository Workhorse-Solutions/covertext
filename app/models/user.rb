class User < ApplicationRecord
  belongs_to :account

  has_secure_password

  ROLES = %w[owner admin].freeze

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }, allow_nil: true

  def owner?
    role == "owner"
  end

  RESET_TOKEN_EXPIRY = 2.hours

  def generate_password_reset_token!
    token = SecureRandom.urlsafe_base64(32)
    digest = BCrypt::Password.create(token, cost: BCrypt::Engine::MIN_COST)

    update!(
      reset_password_token_digest: digest,
      reset_password_sent_at: Time.current
    )

    token
  end

  def password_reset_token_valid?(token)
    return false if reset_password_token_digest.blank?
    return false if reset_password_sent_at.blank?
    return false if reset_password_sent_at < RESET_TOKEN_EXPIRY.ago

    BCrypt::Password.new(reset_password_token_digest).is_password?(token)
  end

  def clear_password_reset_token!
    update!(reset_password_token_digest: nil, reset_password_sent_at: nil)
  end
end
