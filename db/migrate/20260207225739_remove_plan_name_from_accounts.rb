class RemovePlanNameFromAccounts < ActiveRecord::Migration[8.1]
  def change
    remove_column :accounts, :plan_name, :string
  end
end
