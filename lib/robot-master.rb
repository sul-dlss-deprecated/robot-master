# Mediates jobs from the Workflow service to the Resque priority queues.
module RobotMaster
  # e.g., `1.2.3`
  VERSION = File.read(File.join(File.dirname(__FILE__), '..', 'VERSION')).strip
end

require 'robot-master/queue'
require 'robot-master/workflow'
