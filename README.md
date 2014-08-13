# robot-master

Mediates jobs from the Workflow service to the Resque priority queues.

## Configuration

Your `config/environments/ENVIRONMENT.rb` should have (see `config/example_environment.rb`):

    WORKFLOW_URL = 'http://127.0.0.1/workflow/'
    REDIS_URL = '127.0.0.1:6379/resque:mynamespace' # hostname:port[:db][/namespace]
    ENV['ROBOT_ENVIRONMENT'] ||= 'development'
    ENV['ROBOT_LOG'] ||= 'stdout'
    ENV['ROBOT_LOG_LEVEL'] ||= 'debug'
    ENV['RESTCLIENT_LOG'] ||= 'stdout'

For processes that do not need Resque queues, use the `skip-queue` attribute flag in `config/workflows`.

    <process name="foobar" skip-queue="true"/>

To limit Resque queues, use the `queue-limit` attribute flag in `config/workflows`.

    <process name="foobar" queue-limit="10"/>

For debugging, to view HTTP traffic use:

    RESTCLIENT_LOG=stdout

## Usage

There are 2 command-line programs: `robot-master` and `controller`:

    Usage:  robot-master [flags] [repo:]workflow
            --repository=REPOSITORY      Use the given repository (default: dor)
            --environment=ENV            Use the given environment (default: development)
            --log-level=LEVEL            Use the given log-level (default: info)
            --log=FILE                   Use the given log file (default: robot-master.log)
        -R, --repeat-every=SECONDS       Keep running every SECONDS in an infinite loop
        -v, --verbose                    Run verbosely, use multiple times for debug level output
      
   
If using `controller` then you also need to edit `config/environments/bluepill_*.rb`
     
    Usage: controller ( boot | quit )
           controller ( start | status | stop | restart | log ) [worker]
           controller [--help]

    Example:
      % controller boot    # start bluepilld and jobs
      % controller status  # check on status of jobs
      % controller log dor_accessionWF_descriptive-metadata # view log for worker
      % controller stop    # stop jobs
      % controller quit    # stop bluepilld

    Environment:
      BLUEPILL_BASEDIR - where bluepill stores its state (default: run/bluepill)
      BLUEPILL_LOGFILE - output log (default: log/bluepill.log)
      ROBOT_ENVIRONMENT - (default: development)
      
Environment variables supported:

    ROBOT_ENVIRONMENT
    ROBOT_LOG_LEVEL
    ROBOT_LOG
    RESTCLIENT_LOG
    
    
## `robot-master` operation

To run all of the workflows, use:

    ROBOT_ENVIRONMENT=production controller boot
    
To run just the `accessionWF` workflow:

in production:

    bin/robot-master --repeat-every=60 --environment=production dor:accessionWF
    
for testing:

    bin/robot-master --repeat-every=60 --environment=testing dor:accessionWF
  
for development (runs once with debugging):

    bin/robot-master -vv dor:accessionWF

To enable status updates in the Workflow service you need to configure the environment
variable `ROBOT_MASTER_ENABLE_UPDATE_WORKFLOW_STATUS="yes"`. The status updates will mark
items as `queued` before queueing them into the Resque priority queue (WARNING: be sure
you want to enable this!)

## Algorithm

in pseudo-code:

    foreach repository r do
      foreach workflow w do
        foreach process-step s do
          foreach lane l do
            if queue for step s lane l need jobs then within transaction do
              jobs = fetch N jobs with 'ready' status from lane l step s from workflow service 
              jobs.each do |job|
                mark job as 'queued' in workflow service
              end
            end
            jobs.each do |job|
              enqueue job into Resque queue
              -- later job runs
            end
          end
        end
      end
    end

## Changes

* `v1.0.0`: Initial version
* `v1.0.1`: Update `bin/robot-status-board` to include all statuses

