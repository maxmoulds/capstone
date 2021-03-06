class AddSupportIdentifierToUsers < ActiveRecord::Migration
  def change
    enable_extension :citext

    add_column :users, :support_identifier, :citext

    add_index :users, :support_identifier, unique: true

    User.find_each do |user|
      User.where(id: user.id).update_all(support_identifier: user.generate_support_identifier)
    end

    change_column_null :users, :support_identifier, false
  end
end
