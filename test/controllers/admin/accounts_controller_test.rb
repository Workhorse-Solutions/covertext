require "test_helper"

module Admin
  class AccountsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @owner = users(:john_owner)
      @admin = users(:bob_admin)
      @account = @owner.account
    end

    test "requires authentication" do
      get admin_account_path
      assert_redirected_to login_path
    end

    test "requires owner role" do
      sign_in(@admin)
      get admin_account_path
      assert_redirected_to admin_requests_path
      assert_equal "Only account owners can access account settings.", flash[:alert]
    end

    test "owner can access account settings" do
      sign_in(@owner)
      get admin_account_path
      assert_response :success
    end

    test "shows account name" do
      sign_in(@owner)
      get admin_account_path
      assert_select "input[name='account[name]'][value=?]", @account.name
    end

    test "shows agencies list" do
      sign_in(@owner)
      get admin_account_path
      assert_select "table tbody tr", count: @account.agencies.count
    end

    test "shows subscription status" do
      @account.update!(subscription_status: "active", plan_name: "pilot")
      sign_in(@owner)
      get admin_account_path
      assert_select ".badge", text: /Active/
      assert_select "p", text: /Pilot/
    end

    test "owner can update account name" do
      sign_in(@owner)
      patch admin_account_path, params: { account: { name: "Updated Name" } }
      assert_redirected_to admin_account_path
      assert_equal "Account updated successfully.", flash[:notice]
      @account.reload
      assert_equal "Updated Name", @account.name
    end

    test "update fails with blank name" do
      sign_in(@owner)
      patch admin_account_path, params: { account: { name: "" } }
      assert_response :unprocessable_entity
    end

    test "admin cannot update account" do
      sign_in(@admin)
      patch admin_account_path, params: { account: { name: "Hacked" } }
      assert_redirected_to admin_requests_path
      @account.reload
      assert_not_equal "Hacked", @account.name
    end

    test "owner sees Account link in nav" do
      sign_in(@owner)
      get admin_requests_path
      assert_select "a[href=?]", admin_account_path, text: "Account"
    end

    test "admin does not see Account link in nav" do
      sign_in(@admin)
      get admin_requests_path
      assert_select "a[href=?]", admin_account_path, count: 0
    end
  end
end
