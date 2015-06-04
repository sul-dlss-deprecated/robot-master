module Resque
  module Plugins
    module ResqueRobotMaster
      module Server
        VIEW_PATH = File.join(File.dirname(__FILE__), 'server', 'views')
        def self.registered(app)
          app.get '/robotmaster' do
            plugin_view :resquerobotmaster
          end
          app.get '/statusboard' do
            plugin_view :resquestatusboard
          end
          app.helpers do
            def plugin_view(filename, options = {}, locals = {})
              erb(File.read(File.join(::Resque::Plugins::ResqueRobotMaster::Server::VIEW_PATH, "#{filename}.erb")), options, locals)
            end
          end
          app.tabs << 'RobotMaster'
          app.tabs << 'StatusBoard'
        end
      end
    end
  end
end
