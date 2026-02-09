
class MarketingController < ApplicationController
  skip_before_action :require_authentication, only: [ :index, :privacy, :terms, :sms_consent ]

  def index
    # Public marketing homepage
  end

  def privacy
    # Privacy Policy page
  end

  def terms
    # Terms of Service page
  end

  def sms_consent
    # SMS Consent Policy page
  end
end
