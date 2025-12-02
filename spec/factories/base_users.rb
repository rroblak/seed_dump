FactoryBot.define do
  factory :base_user do
    name { 'Test User' }
    email { 'user@example.com' }
  end

  factory :admin_user do
    name { 'Admin User' }
    email { 'admin@example.com' }
  end

  factory :guest_user do
    name { 'Guest User' }
    email { 'guest@example.com' }
  end
end
