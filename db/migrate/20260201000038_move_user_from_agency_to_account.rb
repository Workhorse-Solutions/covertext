class MoveUserFromAgencyToAccount < ActiveRecord::Migration[8.1]
  def change
    # Add account_id to users
    add_reference :users, :account, null: false, foreign_key: true

    # Remove agency_id from users
    remove_reference :users, :agency, foreign_key: true
  end
end
