
Rails.application.configure do
  # Configure Stripe API key from credentials or environment
  # Prefer credentials (encrypted) over ENV vars for consistency
  Stripe.api_key = begin
    Rails.application.credentials.dig(:stripe, :secret_key)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end || ENV["STRIPE_SECRET_KEY"]
end
