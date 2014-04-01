$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

ENV['ROBOT_ENVIRONMENT'] ||= 'development'
ENV['ROBOT_LOG'] ||= '/dev/null'
ENV['ROBOT_LOG_LEVEL'] ||= 'debug'

require 'simplecov'
SimpleCov.start

require 'bundler/setup'
Bundler.require(:default, :development)

require 'rubygems'
require 'rspec'
require 'awesome_print'
require 'equivalent-xml'

RSpec.configure do |config|
  
end

Rails = Object.new unless defined? Rails