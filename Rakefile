require 'rubygems'
require 'rake'
require 'version_bumper'

Dir.glob('lib/tasks/*.rake').each { |r| import r }

require 'rspec/core/rake_task'

desc 'Run specs'
RSpec::Core::RakeTask.new(:spec)

task :clean do
  puts 'Cleaning old coverage.data'
  FileUtils.rm('coverage.data') if File.exist? 'coverage.data'
end

task :restart do
  puts 'Restarting...'
end

task default: [:spec]
