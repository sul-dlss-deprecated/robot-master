source 'https://rubygems.org'

gem 'dor-workflow-service', '~> 1.6.2'
gem 'nokogiri', '~> 1.6.1'
gem 'resque', '~> 1.25.2'
gem 'robot-controller', '~> 0.2.0'

group :development do
  gem 'awesome_print'
  gem 'equivalent-xml', '~> 0.3.0' # 0.4.x breaks RSpec
  gem 'mock_redis', '~> 0.12.0'
  gem 'pry'
  gem 'rake'
  gem 'rdoc'
  gem 'redcarpet' # provides Markdown
  gem 'rspec'
  gem 'simplecov'
  gem 'version_bumper'
  gem 'yard'
end

group :deployment do
  source "http://sul-gems-prod.stanford.edu"
  gem 'capistrano', '~> 3.0'
  gem 'capistrano-bundler', '~> 1.1'
  gem 'lyberteam-capistrano-devel', '~> 3.0.0.pre1'
end
