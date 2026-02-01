require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seeds create expected records without errors" do
    # Clear and reload seeds
    [ AuditEvent, Delivery, MessageLog, Request, Document, Policy, Client, ConversationSession, User, Agency, Account ].each(&:destroy_all)

    assert_nothing_raised do
      load Rails.root.join("db/seeds.rb")
    end

    # Multitenancy model: 1 Account with 2 Agencies
    assert_equal 1, Account.count, "Should create 1 account"
    assert_equal 2, Agency.count, "Should create 2 agencies"
    assert_equal 1, User.count, "Should create 1 user"
    assert_equal 4, Client.count, "Should create 4 clients (2 per agency)"
    assert_equal 10, Policy.count, "Should create 10 policies"
    assert_equal 10, Document.count, "Should create 10 documents"

    # Verify user belongs to account with owner role
    user = User.first
    assert_equal Account.first, user.account
    assert_equal "owner", user.role

    # Verify documents have attached files
    assert_equal 10, Document.joins(:file_attachment).count, "All documents should have attached files"
  end
end
