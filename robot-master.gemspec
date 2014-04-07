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
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']
 
  s.required_rubygems_version = ">= 1.3.6"
  
  s.add_dependency 'dor-workflow-service', '~> 1.6.0'
  s.add_dependency 'nokogiri', '~> 1.6.1'
  s.add_dependency 'resque', '~> 1.25.2'
  s.add_dependency 'robot-controller', '~> 0.2.0'
  
  s.add_development_dependency 'awesome_print'
  s.add_development_dependency 'capistrano'
  # s.add_development_dependency 'capistrano-bundler'
  s.add_development_dependency 'equivalent-xml', '~> 0.3.0' # 0.4.x breaks RSpec
  s.add_development_dependency 'mock_redis'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'redcarpet' # provides Markdown
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'version_bumper'
  s.add_development_dependency 'yard'
 
end
