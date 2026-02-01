require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires first_name" do
    user = User.new(account: accounts(:reliable_group), last_name: "Doe", email: "test@example.com", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:first_name], "can't be blank"
  end

  test "requires last_name" do
    user = User.new(account: accounts(:reliable_group), first_name: "John", email: "test@example.com", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:last_name], "can't be blank"
  end

  test "requires email" do
    user = User.new(account: accounts(:reliable_group), first_name: "John", last_name: "Doe", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "requires unique email" do
    duplicate = User.new(account: accounts(:acme_group), first_name: "Jane", last_name: "Doe", email: users(:john_owner).email, password: "password")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "creates user with valid attributes" do
    user = User.new(account: accounts(:reliable_group), first_name: "John", last_name: "Doe", email: "newuser@example.com", password: "password")
    assert user.valid?
    assert user.save
  end

  test "role defaults to admin" do
    user = User.create!(account: accounts(:reliable_group), first_name: "Test", last_name: "User", email: "roletest@example.com", password: "password")
    assert_equal "admin", user.role
  end

  test "has_secure_password is enabled" do
    user = users(:john_owner)
    assert user.authenticate("password123")
    assert_not user.authenticate("wrongpassword")
  end

  test "owner? returns true for owner role" do
    user = users(:john_owner)
    assert user.owner?
  end

  test "owner? returns false for admin role" do
    user = users(:bob_admin)
    assert_not user.owner?
  end

  test "validates role inclusion" do
    user = User.new(account: accounts(:reliable_group), first_name: "Test", last_name: "User", email: "invalid@example.com", password: "password", role: "invalid")
    assert_not user.valid?
    assert_includes user.errors[:role], "is not included in the list"
  end
end
