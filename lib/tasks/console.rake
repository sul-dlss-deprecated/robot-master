desc 'Run a console'
task :console, :ROBOT_ENVIRONMENT do |_t, args|
  args.with_defaults(ROBOT_ENVIRONMENT: 'development')

  ENV['ROBOT_ENVIRONMENT'] ||= args[:ROBOT_ENVIRONMENT]
  require_relative '../../config/boot'

  begin
    require 'pry'
    IRB = Pry
  rescue LoadError
    require 'irb'
  end

  IRB.start
end
