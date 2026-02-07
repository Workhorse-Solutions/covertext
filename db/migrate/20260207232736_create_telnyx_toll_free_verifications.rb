class CreateTelnyxTollFreeVerifications < ActiveRecord::Migration[8.1]
  def change
    create_table :telnyx_toll_free_verifications do |t|
      t.references :agency, null: false, foreign_key: true, index: true
      t.string :telnyx_number, null: false
      t.string :telnyx_request_id
      t.string :status, null: false, default: "draft"
      t.jsonb :payload, null: false, default: {}
      t.text :last_error
      t.datetime :submitted_at
      t.datetime :last_status_at

      t.timestamps
    end

    add_index :telnyx_toll_free_verifications, [ :agency_id, :telnyx_number ], unique: true, name: "index_telnyx_tf_verifications_on_agency_and_number"
    add_index :telnyx_toll_free_verifications, :status
  end
end
