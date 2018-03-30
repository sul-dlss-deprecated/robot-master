$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

ENV['ROBOT_ENVIRONMENT'] ||= 'local'
ENV['ROBOT_LOG'] ||= '/dev/null'
ENV['ROBOT_LOG_LEVEL'] ||= 'debug'

require 'simplecov'
SimpleCov.start

require 'bundler/setup'
Bundler.require(:default, :test)

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
