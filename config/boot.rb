$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rubygems'
require 'bundler/setup'
require 'logger'

ENV['ROBOT_LOG'] ||= 'stdout'
ENV['ROBOT_LOG_LEVEL'] ||= 'info'
ROBOT_LOG = Logger.new(ENV['ROBOT_LOG'].downcase == 'stdout' ? STDOUT : ENV['ROBOT_LOG'])
ROBOT_LOG.level = Logger::SEV_LABEL.index(ENV['ROBOT_LOG_LEVEL'].upcase) || Logger::INFO

# if running using stdout, then run unbuffered
STDOUT.sync = true if ENV['ROBOT_LOG'].downcase == 'stdout'

# Load the environment file based on Environment.  Default to development
require 'dor-services'
ENV['ROBOT_ENVIRONMENT'] ||= 'development'
require File.expand_path(File.join(File.dirname(__FILE__), 'environments', ENV['ROBOT_ENVIRONMENT']))

# @see https://github.com/sul-dlss/dor-workflow-service
require 'dor-workflow-service'
WORKFLOW_URL = 'http://127.0.0.1:8080/workflow' unless defined? WORKFLOW_URL
WORKFLOW_TIMEOUT = 60 unless defined? WORKFLOW_TIMEOUT
Dor::WorkflowService.configure(WORKFLOW_URL, timeout: WORKFLOW_TIMEOUT)

# Load Resque configuration and controller
require 'resque'
begin
  REDIS_URL = '127.0.0.1:6379/resque:development' unless defined? REDIS_URL
  if defined? REDIS_TIMEOUT
    _server, _namespace = REDIS_URL.split('/', 2)
    _host, _port, _db = _server.split(':')
    _redis = Redis.new(host: _host, port: _port, thread_safe: true, db: _db, timeout: REDIS_TIMEOUT.to_f)
    Resque.redis = Redis::Namespace.new(_namespace, redis: _redis)
  else
    Resque.redis = REDIS_URL
  end
end

require 'active_support/core_ext' # camelcase
require 'lyber_core'
LyberCore::Log.set_logfile(ENV['ROBOT_LOG'].downcase == 'stdout' ? STDOUT : ENV['ROBOT_LOG']) # Fixes #35
require 'robot-master'
