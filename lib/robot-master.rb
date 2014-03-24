# Mediates jobs from the Workflow service to the Resque priority queues.
module RobotMaster
  # e.g., `VERSION => '1.2.3'`
  VERSION = File.read(File.join(File.dirname(__FILE__), '..', 'VERSION')).strip
end

require 'robot-master/priority'
require 'robot-master/workflow'