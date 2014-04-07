set :deployment_host, 'sul-lyberservices-dev.stanford.edu'
set :rails_env, "development"
set :repository,  "."
set :branch, "master"
set :bundle_without, [:deployment,:production]

role :web, deployment_host
role :app, deployment_host
role :db,  deployment_host, :primary => true