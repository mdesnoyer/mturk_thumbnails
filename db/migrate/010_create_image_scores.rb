class CreateImageScores < ActiveRecord::Migration
  def change
    create_table :image_scores do |t|
      t.string :image
      t.float :valence
      t.string :stimset
      t.integer :valid_keeps
      t.integer :valid_returns
    end
  end
end
