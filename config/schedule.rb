set :output, '/home/lyberadmin/robot-master/current/log/crondebug.log'

every :day, at: '1:36am', roles: [:app] do
  command "BUNDLE_GEMFILE=/home/lyberadmin/robot-master/current/Gemfile /usr/local/rvm/gems/ruby-2.2.4@global/bin/bundle exec /home/lyberadmin/robot-master/current/bin/robot-sweeper --environment=#{environment} --log=/home/lyberadmin/robot-master/current/log/sweeper.log"
end
