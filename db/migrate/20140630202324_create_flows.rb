class CreateFlows < ActiveRecord::Migration
  def change
    create_table :flows do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end

    add_index :flows, :slug, unique: true
  end
end
