# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
  
Gem::Specification.new do |s|
  s.name        = "robot-master"
  s.version     = "0.0.1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Darren Hardy"]
  s.email       = ["drh@stanford.edu"]
  s.homepage    = "http://github.com/sul-dlss/robot-master"
  s.summary     = "Moderator for migrating jobs from the Workflow service to the Resque queues"
 
  s.required_rubygems_version = ">= 1.3.6"
  
  s.add_dependency 'resque', '~> 1.25.2'
  s.add_dependency 'druid-tools', '~> 0.3.0'
  s.add_dependency 'dor-workflow-service', '~> 1.5.1'
  
  s.add_development_dependency "rake", '~> 10.1.1'
  s.add_development_dependency "rdoc"
  s.add_development_dependency "rspec"
  s.add_development_dependency "yard"
 
  s.files        = Dir.glob("lib/**/*") + %w(LICENSE README.md)
  s.require_path = 'lib'
end
