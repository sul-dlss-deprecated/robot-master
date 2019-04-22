source 'https://rubygems.org'

gem 'awesome_print'
gem 'nokogiri', '~> 1.10.3'
gem 'parallel'
gem 'resque', '~> 1.27.4'
gem 'whenever'
gem 'faraday'

gem 'dor-services', '>= 5.8.2'
gem 'lyber-core', '>= 4.0.3'
gem 'robot-controller', '>= 2.0.1'
gem 'bluepill', '>= 0.1.3'

group :development, :test do
  gem 'pry'
  gem 'rake'
  gem 'rubocop', '~> 0.59.2'
end

group :test do
  gem 'coveralls', require: false
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
