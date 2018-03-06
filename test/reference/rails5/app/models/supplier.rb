class Supplier < ApplicationRecord
  has_one :account
  has_one :account_history, through: :account
end
