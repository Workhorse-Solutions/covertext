class AddAccountIdToAgencies < ActiveRecord::Migration[8.1]
  def change
    # Add account_id foreign key
    add_reference :agencies, :account, null: false, foreign_key: true

    # Add active column for agency activation status
    add_column :agencies, :active, :boolean, default: true, null: false

    # Remove Stripe billing columns (now on Account)
    remove_index :agencies, :stripe_customer_id
    remove_index :agencies, :stripe_subscription_id
    remove_column :agencies, :stripe_customer_id, :string
    remove_column :agencies, :stripe_subscription_id, :string
    remove_column :agencies, :subscription_status, :string
    remove_column :agencies, :plan_name, :string
  end
end
