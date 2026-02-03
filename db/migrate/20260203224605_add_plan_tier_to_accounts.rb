class AddPlanTierToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :plan_tier, :string, default: "starter", null: false
  end
end
