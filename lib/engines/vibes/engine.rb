module Vibes
  class Engine < ::Rails::Engine
    isolate_namespace Vibes
    
    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
      g.assets false
      g.helper false
    end
    
    # Configure paths for development vs Fly.io
    initializer "vibes.configure_paths", before: :set_autoload_paths do |app|
      if Rails.env.development? && !ENV['FLY_APP_NAME']
        # Local development: use lib/engines/vibes
        vibes_root = Rails.root.join('lib', 'engines', 'vibes')
      else
        # Fly.io: use mounted volume
        vibes_root = Pathname.new('/mnt/vibes')
      end
      
      # Only add paths if the directory exists
      if vibes_root.exist?
        app.config.paths['app/models'] << vibes_root.join('app', 'models').to_s
        app.config.paths['app/views'] << vibes_root.join('app', 'views').to_s
        app.config.paths['app/controllers'] << vibes_root.join('app', 'controllers').to_s
        app.config.paths['db/migrate'] << vibes_root.join('db', 'migrate').to_s
        app.config.autoload_paths << vibes_root.join('lib').to_s
        
        # Add services path (Rails doesn't have this by default)
        services_path = vibes_root.join('app', 'services').to_s
        app.config.autoload_paths << services_path if Dir.exist?(services_path)
        
        Rails.logger.info "🎵 Vibes engine loaded from: #{vibes_root}"
      else
        Rails.logger.info "🎵 Vibes engine directory not found at: #{vibes_root}"
      end
    end
  end
end
