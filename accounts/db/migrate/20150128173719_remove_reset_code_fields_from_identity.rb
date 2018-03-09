class RemoveResetCodeFieldsFromIdentity < ActiveRecord::Migration
  def up
    remove_column :identities, :reset_code
    remove_column :identities, :reset_code_expires_at
  end

  def down
    add_column :identities, :reset_code, :string
    add_column :identities, :reset_code_expires_at, :datetime
  end
end
