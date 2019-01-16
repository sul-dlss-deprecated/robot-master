set :output, '/home/lyberadmin/robot-master/current/log/crondebug.log'

every 12.hours, roles: [:app] do
  command "cd /home/lyberadmin/robot-master/current && bundle exec bin/robot-sweeper --environment=#{environment} --log=log/sweeper.log"
end
