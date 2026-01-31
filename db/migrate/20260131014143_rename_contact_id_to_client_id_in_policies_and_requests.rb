class RenameContactIdToClientIdInPoliciesAndRequests < ActiveRecord::Migration[8.1]
  def change
    # Rename foreign key column in policies
    rename_column :policies, :contact_id, :client_id

    # Rename foreign key column in requests
    rename_column :requests, :contact_id, :client_id
  end
end
