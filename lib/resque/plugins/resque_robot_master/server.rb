module Resque
  module Plugins
    module ResqueRobotMaster

      module Server

        VIEW_PATH = File.join(File.dirname(__FILE__), 'server', 'views')

        def self.registered(app)
          app.get "/robotmaster" do
            resquerobotmaster_view :resquerobotmaster
          end

          app.helpers do
            def resquerobotmaster_view(filename, options = {}, locals = {})
              erb(File.read(File.join(::Resque::Plugins::ResqueRobotMaster::Server::VIEW_PATH, "#{filename}.erb")), options, locals)
            end
          end
          
          app.tabs << "RobotMaster"
        end

      end

    end
  end
end
