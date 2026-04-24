class AddLastCheckedDateToPrograms < ActiveRecord::Migration[7.1]
  def change
    add_column :programs, :last_checked_date, :date
  end
end