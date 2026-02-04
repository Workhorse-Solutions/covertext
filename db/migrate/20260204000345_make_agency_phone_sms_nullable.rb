class MakeAgencyPhoneSmsNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :agencies, :phone_sms, true
  end
end
