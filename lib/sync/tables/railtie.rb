module Sync
  module Tables
    class Railtie < Rails::Railtie
      rake_tasks do
        load 'tasks/publications.rake'
      end
    end
  end
end
