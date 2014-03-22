$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'bundler/setup'
Bundler.require(:default, :development)

require 'rubygems'
require 'rspec'
require 'awesome_print'
require 'equivalent-xml'


RSpec.configure do |config|
  
end

Rails = Object.new unless defined? Rails