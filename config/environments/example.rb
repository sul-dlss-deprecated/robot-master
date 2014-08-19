cert_dir = File.join(File.dirname(__FILE__), "..", "certs")

Dor::Config.configure do
  solrizer.url 'http://example.com/solr/collection'
  fedora.url 'https://example.com/fedora'

  ssl do
    cert_file File.join(cert_dir,"example.crt")
    key_file File.join(cert_dir,"example.key")
    key_pass ''
  end
end

# @see https://github.com/sul-dlss/dor-workflow-service
WORKFLOW_URL = 'http://127.0.0.1/workflow/'
WORKFLOW_TIMEOUT = 60 # in seconds

# @see http://rubydoc.info/gems/redis/3.0.7/file/README.md
# @see https://github.com/resque/resque
#
# Set the redis connection. Takes any of:
#   String - a redis url string (e.g., 'redis://host:port')
#   String - 'hostname:port[:db][/namespace]'
#   Redis - a redis connection that will be namespaced :resque
#   Redis::Namespace - a namespaced redis connection that will be used as-is
#   Redis::Distributed - a distributed redis connection that will be used as-is
#   Hash - a redis connection hash (e.g. {:host => 'localhost', :port => 6379, :db => 0})
REDIS_URL = '127.0.0.1:6379/resque:development' # hostname:port[:db][/namespace]

ENV['ROBOT_ENVIRONMENT'] ||= 'development'
ENV['ROBOT_MASTER_ENABLE_UPDATE_WORKFLOW_STATUS'] ||= 'yes'
ENV['ROBOT_MASTER_CONCURRENT'] ||= '0'