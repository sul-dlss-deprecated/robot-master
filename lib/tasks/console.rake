desc "Run console; defaults to IRB='pry'"
task :console, :IRB do |t, args|
  irb = args[:IRB].nil?? 'pry' : args[:IRB]
  sh irb, "-r", "#{File.dirname(__FILE__)}/../../config/boot.rb"
end
