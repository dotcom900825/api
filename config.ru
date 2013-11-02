require 'sinatra'

require 'rubygems'
require 'bundler'

Bundler.require

require './ipassstore_api_app'

run IpassstoreApiApp

