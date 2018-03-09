class AddResetPasswordCode < ActiveRecord::Migration
  def up
    add_column :identities, :reset_code, :string
    add_column :identities, :reset_code_expires_at, :datetime
  end

  def down
    remove_column :identities, :reset_code
    remove_column :identities, :reset_code_expires_at
  end
end
