class AccountMailer < ApplicationMailer
  def subscription_expiry_warning
    @account = params[:account]
    @user = params[:user]
    @days_remaining = @account.days_until_lockout
    @billing_url = admin_billing_url

    mail(
      to: @user.email,
      subject: "Your CoverText subscription expires in #{@days_remaining} #{"day".pluralize(@days_remaining)}"
    )
  end
end
