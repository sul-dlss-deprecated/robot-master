robot-master
============

Mediates jobs from the Workflow service to the Resque priority queues.

Algorithm
---------

    foreach repository do
      foreach workflow do
        foreach process-step do
          if priority queue needs jobs or priority jobs in workflow service
            within transaction do
              jobs = fetch N jobs with 'ready' status by priority from workflow service
              jobs.each do |job|
                mark job as 'queued' in workflow service
              end
            end
            jobs.each do |job|
              enqueue job into Resque priority queue
            end
          end
          foreach job in /failed queue do
            mark job status as 'error' in workflow service if not already marked
          end
        end
      end
    end

Operation
---------

Example command line runs for:

in production:

    ROBOT_ENVIRONMENT=production bin/robot-master --repeat-every=60 dor:accessionWF

for testing:

    bin/robot-master --repeat-every=60 --environment=testing dor:accessionWF
  
for development:

    RESTCLIENT_LOG=stdout bin/robot-master -vv --log-level=debug --log=debug.log dor:accessionWF
  
Usage
-----

    Usage:  robot-master [flags] [repo:]workflow
            --repository=REPOSITORY      Use the given repository (default: dor)
            --environment=ENV            Use the given environment (default: development)
            --log-level=LEVEL            Use the given log-level (default: info)
            --log=FILE                   Use the given log file (default: robot-master.log)
        -R, --repeat-every=SECONDS       Keep running every SECONDS in an infinite loop
        -v, --verbose                    Run verbosely, use multiple times for debug level output
      
      
Environment variables supported:

    ROBOT_ENVIRONMENT
    ROBOT_LOG_LEVEL
    ROBOT_LOG
    RESTCLIENT_LOG
    
Configuration
-------------

Your `config/environments/ENVIRONMENT.rb` should have (see `config/example_environment.rb`):

    WORKFLOW_URL = 'http://127.0.0.1/workflow/'
    REDIS_URL = '127.0.0.1:6379/resque:mynamespace' # hostname:port[:db][/namespace]
    ENV['ROBOT_ENVIRONMENT'] ||= 'development'
    ENV['ROBOT_LOG'] ||= 'stdout'
    ENV['ROBOT_LOG_LEVEL'] ||= 'debug'

For processes that do not need Resque queues, use the `skip-queue` attribute flag.

    <process name="foobar" skip-queue="true"/>

For debugging, to view HTTP traffic use:

    RESTCLIENT_LOG=stdout

Workflow objects
----------------

These are the druids in production for the various workflow objects. `config/workflows` has cached copies of these.

    1   bb163sd6279 DOR sdrIngestWF              
    2   dd778qy4284 DOR dpgImageWF
    3   dz388gs4054 DOR eemsAccessionWF
    4   fy957df3135 DOR digitizationWF
    5   gb941hc6393 DOR googleScannedBookWF
    6   nb274zx7788 DOR disseminationWF
    7   oo000oo0099 hydrusAssemblyWF
    8   rs056hz6024 assemblyWF
    9   sh219xb1690 registrationWF
    10  tm388wy6148 DOR accessionWF
    11  vn914kc9255 DOR etdSubmitWF
    12  yp220bx1022 Versioning Workflow


