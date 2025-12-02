FactoryBot.define do
  factory :review do
    content { 'Great book!' }
    rating { 5 }
    association :book
  end
end
