set :deploy_environment, 'test'
set :whenever_environment, fetch(:deploy_environment)
set :default_env, robot_environment: fetch(:deploy_environment)

server 'sul-lyberservices-test.stanford.edu', user: 'lyberadmin', roles: %w(web app db)

Capistrano::OneTimeKey.generate_one_time_key!
