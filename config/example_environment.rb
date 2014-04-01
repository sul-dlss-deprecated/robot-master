WORKFLOW_URL = 'http://127.0.0.1/workflow/'
REDIS_URL = '127.0.0.1:6379/resque:mynamespace' # hostname:port[:db][/namespace]
ENV['ROBOT_ENVIRONMENT'] ||= 'development'
ENV['ROBOT_LOG'] ||= 'stdout'
ENV['ROBOT_LOG_LEVEL'] ||= 'debug'