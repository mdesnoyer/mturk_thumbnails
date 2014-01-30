class AddTimestampsToUserRejections < ActiveRecord::Migration
    def change
      add_column(:user_rejections, :created_at, :datetime)
      add_column(:user_rejections, :updated_at, :datetime)
    end
end
