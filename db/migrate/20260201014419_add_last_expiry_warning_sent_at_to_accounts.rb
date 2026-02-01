class AddLastExpiryWarningSentAtToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :last_expiry_warning_sent_at, :datetime
  end
end
