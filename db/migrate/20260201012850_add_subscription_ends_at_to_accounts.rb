class AddSubscriptionEndsAtToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :subscription_ends_at, :datetime
  end
end
