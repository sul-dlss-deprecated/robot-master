set :output, '/home/lyberadmin/robot-master/current/log/crondebug.log'

every :day, at: '1:36am', roles: [:app] do
  command "cd /home/lyberadmin/robot-master/current && BUNDLE_GEMFILE=Gemfile /usr/local/rvm/gems/ruby-2.2.4@global/bin/bundle exec bin/robot-sweeper --environment=#{environment} --log=log/sweeper.log"
end
