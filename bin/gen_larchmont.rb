#! /usr/bin/ruby

require 'rubygems'
require 'json'

config = {}

config[:import] = {
  start_year: 2008, # Implies F08...?????
  year_is_at_end_of_period: false, # Larchmont treats the START year as the event year
  load_memorials: true, # To speed testing up (may not be NIL)
  load_children: true, # To speed testing up (may not be NIL)
}

config[:marks] = {
  tribute_bank_account_code: '10-005-11000',
  tribute_income_account_code: '10-010-41100',
  deposit_bank_account_code: '10-005-11000',
  membership_tag_code: 0,
  person_gender_code: 2,
  spouse_gender_code: 3
}

config[:company] = {
  subdomain: 'larchmont',
  name: 'Larchmont Temple',
  fiscal_year_month: 7,
  email: 'email@larchmont.dev'
}

config[:users] = [
  {
    name: 'admin',
    email: 'admin@larchmont.dev',
    subdomain: 'larchmont',
    password: 'admin00',
    password_confirmation: 'admin00',
    role: 'Admin'
  },
]

# Membership codes are: B,F,I,H,A,R,S,M,,P,N,Z,,,\,D
config[:tags] = {
  'B' => {name: 'Non Resident Member', implies: true},
  'F' => {name: 'Full Family Member', implies: true},
  'I' => {name: 'Individiual Member', implies: true},
  'H' => {name: 'Honorary Member', implies: true},
  'A' => {name: 'Adjusted Member', implies: true},
  'R' => {name: 'Religious School Member', implies: true},
  'S' => {name: 'Single Member', implies: true},
  'M' => {name: 'M-Member', implies: true},
  'P' => {name: 'P-Member', implies: true},
  'N' => {name: 'No Billing Member', implies: true},
  'Z' => {name: 'Z-Member', implies: true},
  'D' => {name: 'D-Member', implies: true}
}

path = File.expand_path('../../config/larchmont.json', __FILE__)
File.open(path, 'w') {|f| f.write(config.to_json) }

puts "Created [larchmont.json] config file..."
