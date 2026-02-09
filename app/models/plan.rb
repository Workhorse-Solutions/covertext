
# Plan represents subscription tier information for CoverText
# This is not an ActiveRecord model - it's a simple value object for plan metadata
class Plan
  TIERS = {
    starter: {
      name: "Starter",
      monthly_price: 49,
      yearly_price: 490,
      price_display: "$49/month",
      description: "Perfect for small agencies",
      features: [
        "1 agency location",
        "Unlimited text messages",
        "Insurance card delivery",
        "Policy lookup automation",
        "Email support"
      ]
    },
    professional: {
      name: "Professional",
      monthly_price: 99,
      yearly_price: 950,
      price_display: "$99/month",
      description: "Scale across multiple locations",
      features: [
        "Up to 3 agency locations",
        "Unlimited text messages",
        "All Starter features",
        "Custom branding & messaging",
        "Priority support"
      ]
    },
    enterprise: {
      name: "Enterprise",
      monthly_price: 199,
      yearly_price: 1990,
      price_display: "$199/month",
      description: "For large agency groups",
      features: [
        "Unlimited agency locations",
        "Unlimited text messages",
        "All Professional features",
        "API access & integrations",
        "Dedicated account manager"
      ]
    }
  }.freeze

  def self.info(tier, interval = :monthly)
    plan_data = TIERS[tier.to_sym] || TIERS[:starter]

    # Add dynamic price display based on interval
    plan_data.merge(
      monthly_price_display: "$#{plan_data[:monthly_price]}/month",
      yearly_price_display: "$#{plan_data[:yearly_price]}/year",
      price_display: interval == :yearly ? "$#{plan_data[:yearly_price]}/year" : "$#{plan_data[:monthly_price]}/month"
    )
  end

  def self.valid?(tier)
    return false if tier.nil?
    TIERS.key?(tier.to_sym)
  end

  def self.all
    TIERS.keys
  end

  def self.default
    :starter
  end
end
