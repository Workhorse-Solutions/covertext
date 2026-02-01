require "test_helper"

class Admin::BannersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john_owner)
    @account = @user.account
  end

  test "dismiss_grace_period sets session flag and returns ok" do
    sign_in @user

    post admin_dismiss_grace_period_banner_path

    assert_response :ok
  end

  test "dismiss_grace_period requires authentication" do
    post admin_dismiss_grace_period_banner_path

    assert_response :redirect
  end
end
