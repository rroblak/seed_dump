FactoryBot.define do
  factory :sample do
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
    # Define created_at and updated_at explicitly as they are used in specs
    created_at { DateTime.parse('July 20, 1969 20:18 UTC') }
    updated_at { DateTime.parse('November 10, 1989 4:20 UTC') }
  end
end
