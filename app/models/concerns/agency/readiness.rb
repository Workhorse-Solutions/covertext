module Agency::Readiness
  extend ActiveSupport::Concern

  def subscription_ready?
    account.subscription_active?
  end

  def phone_ready?
    phone_sms.present?
  end

  def verification_ready?
    return false unless phone_ready?

    telnyx_toll_free_verifications
      .where(telnyx_number: phone_sms)
      .where.not(status: %w[draft rejected])
      .exists?
  end

  def fully_ready?
    subscription_ready? && phone_ready? && verification_ready?
  end
end
