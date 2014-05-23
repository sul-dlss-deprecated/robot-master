$:.unshift File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))

require 'rubygems'
require 'bundler/setup'
require 'logger'

# Load the environment file based on Environment.  Default to development
ENV['ROBOT_ENVIRONMENT'] ||= 'development'
require File.expand_path(File.join(File.dirname(__FILE__), 'environments', ENV['ROBOT_ENVIRONMENT']))

ENV['ROBOT_LOG'] ||= 'stdout'
ENV['ROBOT_LOG_LEVEL'] ||= 'info'
ROBOT_LOG = Logger.new(ENV['ROBOT_LOG'].downcase == 'stdout' ? STDOUT : ENV['ROBOT_LOG'])
ROBOT_LOG.level = Logger::SEV_LABEL.index(ENV['ROBOT_LOG_LEVEL'].upcase) || Logger::INFO

# if running under debugging and using stdout, then run unbuffered
STDOUT.sync = true if ENV['ROBOT_LOG_LEVEL'].downcase == 'debug' and ENV['ROBOT_LOG'].downcase == 'stdout'

# @see https://github.com/sul-dlss/dor-workflow-service
require 'dor-workflow-service'
WORKFLOW_TIMEOUT = 60 unless defined? WORKFLOW_TIMEOUT
Dor::WorkflowService.configure(WORKFLOW_URL, timeout: WORKFLOW_TIMEOUT)

# @see http://rubydoc.info/gems/redis/3.0.7/file/README.md
# @see https://github.com/resque/resque
#
# Set the redis connection. Takes any of:
#   String - a redis url string (e.g., 'redis://host:port')
#   String - 'hostname:port[:db][/namespace]'
#   Redis - a redis connection that will be namespaced :resque
#   Redis::Namespace - a namespaced redis connection that will be used as-is
#   Redis::Distributed - a distributed redis connection that will be used as-is
#   Hash - a redis connection hash (e.g. {:host => 'localhost', :port => 6379, :db => 0})
require 'resque'
Resque.redis = REDIS_URL

require 'active_support/core_ext' # camelcase
require 'robot-master'







