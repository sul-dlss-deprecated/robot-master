# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'robot-master'

Gem::Specification.new do |s|
  s.name        = "robot-master"
  s.version     = RobotMaster::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Darren Hardy"]
  s.email       = ["drh@stanford.edu"]
  s.homepage    = "http://github.com/sul-dlss/robot-master"
  s.summary     = "Moderator for migrating jobs from the Workflow service to the Resque queues"
  s.has_rdoc    = true
  s.licenses    = ['ALv2', 'Stanford University']
  
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.executables   = ['robot-master']
  s.require_paths = ['lib']
   
  s.required_rubygems_version = ">= 1.3.6"
end
