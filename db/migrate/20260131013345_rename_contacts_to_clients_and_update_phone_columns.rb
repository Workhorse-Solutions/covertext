class RenameContactsToClientsAndUpdatePhoneColumns < ActiveRecord::Migration[8.1]
  def change
    # Rename contacts table to clients
    rename_table :contacts, :clients

    # Rename mobile_phone_e164 to phone_mobile in clients
    rename_column :clients, :mobile_phone_e164, :phone_mobile

    # Rename sms_phone_number to phone_sms in agencies
    rename_column :agencies, :sms_phone_number, :phone_sms
  end
end
