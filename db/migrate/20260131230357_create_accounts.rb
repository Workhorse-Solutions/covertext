class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :stripe_customer_id
      t.string :stripe_subscription_id
      t.string :subscription_status
      t.string :plan_name

      t.timestamps
    end

    add_index :accounts, :stripe_customer_id, unique: true
    add_index :accounts, :stripe_subscription_id, unique: true
  end
end
