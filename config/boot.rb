$:.unshift File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))

require 'rubygems'
require 'bundler/setup'
require 'logger'

# Load the environment file based on Environment.  Default to development
environment = ENV['ROBOT_ENVIRONMENT'] ||= 'development'
env_file = File.expand_path(File.dirname(__FILE__) + "/./environments/#{environment}")
require env_file

ROBOT_LOG = Logger.new(ENV['ROBOT_LOG'] || File.join(File.dirname(__FILE__), "../#{environment}.log"))
ROBOT_LOG.level = Logger::SEV_LABEL.index((ENV['ROBOT_LOG_LEVEL'] || 'info').upcase) || Logger::INFO

require 'dor-workflow-service'
Dor::WorkflowService.configure(WORKFLOW_URL)

require 'resque'
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
Resque.redis = REDIS_URL

require 'active_support/core_ext' # camelcase
require 'druid-tools'
require 'robot-master'







  