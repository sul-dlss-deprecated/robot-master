require 'rubygems'
require 'rake'

Dir.glob('lib/tasks/*.rake').each { |r| import r }

task default: :ci

desc 'run continuous integration suite (tests & rubocop)'
task ci: [:spec, :rubocop]
