class UpdateIndexOnImageChoices < ActiveRecord::Migration
  def self.up
    add_index :image_choices, :worker_id

    ActiveRecord::Base.connection.execute <<-SQL
      CREATE INDEX index_stimset_id ON image_choices (stimset_id varchar_pattern_ops);
    SQL
  end

  def self.down
    remove_index :image_choices, name: :index_stimset_id
    remove_index :image_choices, :worker_id
  end
end
