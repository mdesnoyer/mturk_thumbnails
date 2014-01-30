class AddTimestampsToUserRejections < ActiveRecord::Migration
    def change_table
      add_column(:user_rejections, :created_at, :datetime)
      add_column(:user_rejections, :updated_at, :datetime)
    end
end
