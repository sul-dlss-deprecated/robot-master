source 'https://rubygems.org'

gem 'awesome_print'
gem 'nokogiri'
gem 'parallel'
gem 'resque'
gem 'whenever'
gem 'faraday'

gem 'dor-services', '>= 5.8.2'
gem 'lyber-core', '>= 4.0.3'
gem 'robot-controller', '>= 2.0.1'

# Pin bluepill to master branch of git since the gem release 0.1.2 is
# incompatible with rails 5, can remove this when a new gem is released
gem 'bluepill', git: 'https://github.com/bluepill-rb/bluepill.git'

group :development, :test do
  gem 'equivalent-xml'
  gem 'mock_redis'
  gem 'pry'
  gem 'rake'
  gem 'rdoc'
  gem 'redcarpet' # provides Markdown
  gem 'resque-mock'
  gem 'rspec'
  gem 'rubocop'
  gem 'simplecov'
  gem 'version_bumper'
  gem 'yard'
end

group :deployment do
  gem 'capistrano-bundler'
  gem 'capistrano-passenger'
  gem 'capistrano-rvm'
  gem 'capistrano'
  gem 'dlss-capistrano'
end
