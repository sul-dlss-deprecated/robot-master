$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

ENV['ROBOT_ENVIRONMENT'] ||= 'local'
ENV['ROBOT_LOG'] ||= '/dev/null'
ENV['ROBOT_LOG_LEVEL'] ||= 'debug'

require 'coveralls'
require 'simplecov'
Coveralls.wear!

SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start do
  add_filter 'spec'
end

require 'bundler/setup'
Bundler.require(:default, :test)

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
