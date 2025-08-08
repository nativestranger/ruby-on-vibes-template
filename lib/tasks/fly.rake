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
    
    # Ensure SQLite directory exists and has proper permissions
    puts "📁 Setting up SQLite directory..."
    sh 'mkdir -p /mnt/sqlite_data'
    sh 'chown rails:rails /mnt/sqlite_data'
    
    # Create and migrate database with better error handling
    puts "🗄️ Setting up database..."
    begin
      sh 'bin/rails db:create'
      puts "✅ Database created"
    rescue => e
      puts "⚠️ Database create failed (might already exist): #{e.message}"
    end
    
    begin
      sh 'bin/rails db:migrate'
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
