$:.unshift File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))

require 'rubygems'
require 'bundler/setup'
require 'logger'

# Load the environment file based on Environment.  Default to development
environment = ENV['ROBOT_ENVIRONMENT'] ||= 'development'
ROBOT_LOG = Logger.new(File.join(File.dirname(__FILE__), "../log/#{environment}.log"))
ROBOT_LOG.level = Logger::SEV_LABEL.index((ENV['ROBOT_LOG_LEVEL'] || 'info').upcase) || Logger::INFO

env_file = File.expand_path(File.dirname(__FILE__) + "/./environments/#{environment}")
require env_file

require 'dor-workflow-service'
Dor::WorkflowService.configure(WORKFLOW_URL)

require 'resque'
require 'druid-tools'
require 'robot-master'








  