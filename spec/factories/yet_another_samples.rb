FactoryBot.define do
  factory :yet_another_sample do
    # Use block syntax for attribute definitions
    string   { 'string' }
    text     { 'text' }
    integer  { 42 }
    float    { 3.14 }
    # BigDecimal needs to be initialized within the block
    decimal  { BigDecimal('2.72') }
    # Use standard Ruby DateTime/Time parse methods directly
    datetime { DateTime.parse('July 4, 1776 7:14pm UTC') }
    time     { Time.parse('3:15am UTC') }
    date     { Date.parse('November 19, 1863') }
    binary   { 'binary' }
    boolean  { false }
    # created_at and updated_at are typically handled by ActiveRecord timestamps
    # but can be defined explicitly if needed for specific tests.
    # created_at { Time.now }
    # updated_at { Time.now }
  end
end
