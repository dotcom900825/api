ENV["RACK_ENV"] = "development"

require 'bundler'
Bundler.require :default, :test

require 'minitest/autorun'
require 'minitest/pride'
require 'minitest/spec'
require 'mocha/setup'


# Load the sinatra application
require_relative '../ipassstore_api_app'

# Load the unit helpers
require_relative "support/unit_helpers.rb"

class UnitTest < MiniTest::Spec
  include UnitHelpers

  register_spec_type(/(Unit|Spec|Model)$/, self)

  register_spec_type(self) do |desc|
    true if desc.is_a?(Class)
  end
end
