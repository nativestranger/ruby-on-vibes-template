# commands used to deploy a Rails application
namespace :fly do
  # BUILD step:
  # - changes to the filesystem made here DO get deployed
  # - NO access to secrets, volumes, databases
  # - Failures here prevent deployment
  task :build => 'assets:precompile'

  # RELEASE step:
  # - changes to the filesystem made here are DISCARDED
  # - full access to secrets, databases
  # - failures here prevent deployment
  task :release

  # SERVER step:
  # - changes to the filesystem made here are deployed
  # - full access to secrets, databases
  # - failures here result in VM being started, shutdown, and rolled back
  # to last successful deploy (if any).
  task :server do
    puts "🚀 Starting Fly server setup..."
    
    # Setup shared volume structure
    puts "📁 Setting up shared volume structure..."
    sh 'mkdir -p /mnt/data/sqlite'
    sh 'mkdir -p /mnt/data/vibes'
    sh 'chown -R rails:rails /mnt/data'
    
    # Setup Vibes engine on volume
    puts "🎵 Setting up Vibes engine..."
    
    # Copy engine files from local to volume if not already present
    if Dir.exist?('/mnt/data/vibes/app')
      puts "✅ Vibes engine already exists on volume"
    else
      puts "📦 Copying Vibes engine to volume..."
      if Dir.exist?('lib/engines/vibes')
        sh 'cp -r lib/engines/vibes/* /mnt/data/vibes/'
        puts "✅ Vibes engine copied to volume"
      else
        puts "⚠️ Local Vibes engine not found, volume will be empty"
      end
    end
    
    # Create and migrate database with memory-efficient approach
    puts "🗄️ Setting up database..."
    begin
      # Use RAILS_ENV=production but with minimal loading
      sh 'RAILS_ENV=production bin/rails db:create --trace'
      puts "✅ Database created"
    rescue => e
      puts "⚠️ Database create failed (might already exist): #{e.message}"
    end
    
    begin
      # Run migrations with minimal memory usage
      sh 'RAILS_ENV=production bin/rails db:migrate --trace'
      puts "✅ Migrations completed"
    rescue => e
      puts "❌ Migration failed: #{e.message}"
      raise e
    end
    
    # Start the server with proper binding for Fly
    puts "🌐 Starting Rails server on 0.0.0.0:3000..."
    sh 'bin/rails server -p 3000 -b 0.0.0.0'
  end
end
