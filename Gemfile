source 'https://rubygems.org'

gem 'awesome_print'
gem 'nokogiri'
gem 'parallel'
# pin resque, as v1.27 doesn't work with our mocking strategy for tests
gem 'resque', '~> 1.26.0'
gem 'whenever'
gem 'faraday'

gem 'dor-services', '>= 5.8.2'
gem 'lyber-core', '>= 4.0.3'
gem 'robot-controller', '>= 2.0.1'

# Pin bluepill to master branch of git since the gem release 0.1.2 is
# incompatible with rails 5, can remove this when a new gem is released
gem 'bluepill', git: 'https://github.com/bluepill-rb/bluepill.git'

group :development, :test do
  gem 'pry'
  gem 'rake'
  gem 'rubocop'
end

group :test do
  gem 'mock_redis'
  gem 'resque-mock' # must be in
  gem 'rspec'
  gem 'simplecov'
end

group :deployment do
  gem 'capistrano-bundler'
  gem 'capistrano-passenger'
  gem 'capistrano-rvm'
  gem 'capistrano'
  gem 'dlss-capistrano'
end

gem 'honeybadger'
