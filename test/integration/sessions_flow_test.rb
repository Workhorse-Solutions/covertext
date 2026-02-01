require "test_helper"

class SessionsFlowTest < ActionDispatch::IntegrationTest
  test "can login with valid credentials" do
    user = users(:john_owner)

    get login_path
    assert_response :success

    post login_path, params: { email: user.email, password: "password123" }
    assert_redirected_to admin_requests_path
    follow_redirect!
    assert_response :success
  end

  test "cannot login with invalid credentials" do
    post login_path, params: { email: "invalid@example.com", password: "wrong" }
    assert_response :unprocessable_entity
    assert_select ".alert-error"
  end

  test "can logout" do
    user = users(:john_owner)
    sign_in(user)

    delete logout_path
    assert_redirected_to login_path

    # Cannot access admin after logout
    get admin_requests_path
    assert_redirected_to login_path
  end
end
