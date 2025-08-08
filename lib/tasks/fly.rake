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
    # Ensure SQLite directory exists and has proper permissions
    sh 'mkdir -p /mnt/sqlite_data'
    sh 'chown -R rails:rails /mnt/sqlite_data'
    
    # Create and migrate database
    sh 'bin/rails db:create db:migrate'
    
    # Start the server with proper binding for Fly
    sh 'bin/rails server -p 3000 -b 0.0.0.0'
  end
end
