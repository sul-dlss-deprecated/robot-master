cert_dir = File.join(File.dirname(__FILE__), '..', 'certs')

Dor::Config.configure do
  solrizer.url 'http://example.com/solr/collection'
  fedora.url 'https://example.com/fedora'

  ssl do
    cert_file File.join(cert_dir, 'example.crt')
    key_file File.join(cert_dir, 'example.key')
    key_pass ''
  end
end

# @see https://github.com/sul-dlss/dor-workflow-service
WORKFLOW_URL = 'http://127.0.0.1/workflow/'
WORKFLOW_TIMEOUT = 60 # in seconds

REDIS_URL = '127.0.0.1:6379/resque:development' # hostname:port[:db]/namespace
# REDIS_TIMEOUT = '5' # seconds

ENV['ROBOT_ENVIRONMENT'] ||= 'development'
ENV['ROBOT_MASTER_ENABLE_UPDATE_WORKFLOW_STATUS'] ||= 'yes'
ENV['ROBOT_MASTER_CONCURRENT'] ||= '0'
