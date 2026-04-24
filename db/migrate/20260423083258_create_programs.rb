class CreatePrograms < ActiveRecord::Migration[7.1]
  def change
    create_table :programs do |t|
      t.string :name
      t.integer :frequency_type
      t.integer :weekday
      t.integer :week_of_month
      t.date :base_date
      t.boolean :listened

      t.timestamps
    end
  end
end
