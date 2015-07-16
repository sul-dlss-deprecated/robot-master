begin
  require 'yard'
  YARD::Rake::YardocTask.new do |t|
    t.files = ['lib/**/*.rb', 'bin/controller']
    t.options = ['--readme', 'README.md', '-m', 'markdown']
  end

  namespace :yard do
    desc 'Clean up documentation'
    task :clean do
      FileUtils.rm_rf('doc')
    end
  end
rescue LoadError
  abort 'Please install the YARD gem to generate doc.'
end
