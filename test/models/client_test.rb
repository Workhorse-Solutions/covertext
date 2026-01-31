require "test_helper"

class ClientTest < ActiveSupport::TestCase
  test "requires phone_mobile" do
    client = Client.new(agency: agencies(:reliable), first_name: "Test", last_name: "User")
    assert_not client.valid?
    assert_includes client.errors[:phone_mobile], "can't be blank"
  end

  test "requires unique phone_mobile scoped to agency" do
    duplicate = Client.new(agency: agencies(:reliable), phone_mobile: clients(:alice).phone_mobile)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:phone_mobile], "has already been taken"
  end

  test "allows same phone_mobile for different agencies" do
    client = Client.new(agency: agencies(:acme), phone_mobile: clients(:alice).phone_mobile)
    assert client.valid?
  end

  test "creates client with valid attributes" do
    client = Client.new(agency: agencies(:reliable), first_name: "New", last_name: "Client", phone_mobile: "+15559999999")
    assert client.valid?
    assert client.save
  end
end
