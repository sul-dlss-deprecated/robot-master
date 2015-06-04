require './lib/resque/plugins/resque_robot_master/server'

Resque::Server.register Resque::Plugins::ResqueRobotMaster::Server
