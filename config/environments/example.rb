cert_dir = File.join(File.dirname(__FILE__), '..', 'certs')

Dor::Config.configure do
  solr.url 'http://example.com/solr/collection'
  fedora.url 'https://example.com/fedora'

  ssl do
    cert_file File.join(cert_dir, 'example.crt')
    key_file File.join(cert_dir, 'example.key')
    key_pass ''
  end

  workflow do
    url 'https://externalhost/workflow'
    logfile 'log/workflow_service.log'
    shift_age 'weekly'
  end
end

REDIS_URL = '127.0.0.1:6379/resque:development' # hostname:port[:db]/namespace
# REDIS_TIMEOUT = '5' # seconds

ENV['ROBOT_ENVIRONMENT'] ||= 'development'
ENV['ROBOT_MASTER_ENABLE_UPDATE_WORKFLOW_STATUS'] ||= 'yes'
ENV['ROBOT_MASTER_CONCURRENT'] ||= '0'
