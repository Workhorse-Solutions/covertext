class PasswordResetsController < ApplicationController
  skip_before_action :require_authentication

  def new
  end

  def create
    user = User.find_by(email: params[:email].to_s.downcase.strip)

    if user
      token = user.generate_password_reset_token!
      UserMailer.with(user: user, token: token).password_reset.deliver_later
    end

    redirect_to login_path, notice: "If that email exists, we've sent password reset instructions."
  end

  def edit
    @token = params[:token]
  end
end
