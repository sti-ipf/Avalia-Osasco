class AddIndicatorIdToQuestions < ActiveRecord::Migration
  def self.up
    add_column :questions, :indicator_id, :integer
  end

  def self.down
    remove_column :questions, :indicator_id
  end
end
