class CreateImageChoices < ActiveRecord::Migration
  def change
    create_table :image_choices do |t|
      t.string :assignment_id
      t.string :image_one
      t.string :image_two
      t.string :image_three
      t.string :chosen_image
      t.timestamps
    end
  end
end
