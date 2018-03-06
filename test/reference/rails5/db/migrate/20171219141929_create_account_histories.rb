class CreateAccountHistories < ActiveRecord::Migration[5.1]
  def change
    create_table :account_histories do |t|
      t.references :account, foreign_key: true
      t.integer :credit_rating

      t.timestamps
    end
  end
end
