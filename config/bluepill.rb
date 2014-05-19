WORKDIR=File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
WORKFLOW_STEPS = %w{
  dor:accessionWF
  dor:assemblyWF
  dor:disseminationWF
}
REPEAT_EVERY = 15 # seconds

Bluepill.application 'robot-master', 
  :log_file => "#{WORKDIR}/log/bluepill.log" do |app|
  
  [ENV['ROBOT_ENVIRONMENT']].each do |e|
      WORKFLOW_STEPS.each do |wf|
        app.process(wf) do |process|
          process.start_command "bin/robot-master -vv --repeat-every=#{REPEAT_EVERY} #{wf}"

          # process configuration
          process.working_dir = WORKDIR
          process.group = "#{e}"
          process.stdout = process.stderr = "#{WORKDIR}/log/#{e}_#{wf.sub(':', '_')}.log"
          
          # let bluepill manage pid files
          # process.pid_file "#{WORKDIR}/run/#{e}_#{wf.sub(':', '_')}.pid"
          
          # we use bluepill to daemonize
          process.daemonize = true

          # graceful stops
          process.stop_grace_time = 60.seconds
          process.stop_signals = [
            :term, 30.seconds,
            :kill              # no mercy
          ]
          
          # process monitoring
          
          # backoff if process is flapping between states
          # process.checks :flapping, 
          #                :times => 2, :within => 30.seconds, 
          #                :retry_in => 7.seconds
          
          # restart if process runs for longer than 15 mins of CPU time
          # process.checks :running_time, 
          #                :every => 5.minutes, :below => 15.minutes
          
          # restart if CPU usage > 75% for 3 times, check every 10 seconds
          # process.checks :cpu_usage, 
          #                :every => 10.seconds, 
          #                :below => 75, :times => 3,
          #                :include_children => true
          # 
          # restart the process or any of its children 
          # if MEM usage > 100MB for 3 times, check every 10 seconds
          # process.checks :mem_usage, 
          #                :every => 10.seconds, 
          #                :below => 100.megabytes, :times => 3, 
          #                :include_children => true
                         
          # NOTE: there is an implicit process.keepalive
        end
    end
  end
end
