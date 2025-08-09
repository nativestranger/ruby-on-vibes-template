class VibesApiController < ApplicationController
  # Skip CSRF for API calls (we use custom auth)
  skip_before_action :verify_authenticity_token
  before_action :authenticate_vibes_api
  
  # GET /vibes_api/files
  def files
    vibes_root = vibes_engine_root
    
    if vibes_root.exist?
      files = collect_vibes_files(vibes_root)
      render json: { success: true, files: files }
    else
      render json: { success: false, error: "Vibes engine not found" }, status: 404
    end
  end
  
  # GET /vibes_api/files/*path
  def show_file
    file_path = params[:path]
    full_path = vibes_engine_root.join(file_path)
    
    if full_path.exist? && full_path.file? && path_safe?(full_path)
      content = File.read(full_path)
      render json: { 
        success: true, 
        content: content, 
        path: file_path,
        last_modified: File.mtime(full_path).iso8601
      }
    else
      render json: { success: false, error: "File not found or access denied" }, status: 404
    end
  rescue => e
    render json: { success: false, error: e.message }, status: 500
  end
  
  # PUT /vibes_api/files/*path
  def update_file
    file_path = params[:path]
    content = params[:content]
    full_path = vibes_engine_root.join(file_path)
    
    unless path_safe?(full_path)
      render json: { success: false, error: "Invalid file path" }, status: 400
      return
    end
    
    begin
      # Ensure directory exists
      FileUtils.mkdir_p(full_path.dirname)
      
      # Create git commit before changes (for rollback)
      create_git_commit_if_needed("Before editing #{file_path}")
      
      # Write the file
      File.write(full_path, content)
      
      # Create git commit after changes
      create_git_commit_if_needed("Updated #{file_path} via Ruby on Vibes")
      
      Rails.logger.info "🎵 Vibes file updated: #{file_path}"
      
      render json: { 
        success: true, 
        message: "File updated successfully",
        path: file_path,
        last_modified: File.mtime(full_path).iso8601
      }
    rescue => e
      Rails.logger.error "❌ Failed to update vibes file #{file_path}: #{e.message}"
      render json: { success: false, error: e.message }, status: 500
    end
  end
  
  # POST /vibes_api/reload
  def reload
    begin
      Rails.logger.info "🔄 Hot reloading vibes engine..."
      
      # Clear Rails autoload cache to pick up changes
      Rails.application.reloader.reload!
      
      # Force reload of the vibes engine
      if defined?(Vibes::Engine)
        # Clear any cached modules/classes
        Vibes.send(:remove_const, :Engine) if Vibes.const_defined?(:Engine)
        load Rails.root.join('lib', 'engines', 'vibes', 'engine.rb')
      end
      
      Rails.logger.info "✅ Vibes engine hot reload completed"
      
      render json: { 
        success: true, 
        message: "Hot reload completed",
        timestamp: Time.current.iso8601
      }
    rescue => e
      Rails.logger.error "❌ Hot reload failed: #{e.message}"
      render json: { success: false, error: e.message }, status: 500
    end
  end
  
  private
  
  def authenticate_vibes_api
    # Prefer static token for cross-app auth
    static_token = request.headers['X-Vibes-Token'].to_s
    if ENV['VIBES_API_TOKEN'].present?
      unless ActiveSupport::SecurityUtils.secure_compare(static_token, ENV['VIBES_API_TOKEN'].to_s)
        render json: { error: 'Unauthorized' }, status: 401 and return
      end
      return
    end

    # Fallback to signed verifier if no static token configured
    auth_header = request.headers['X-Vibes-Auth']
    unless auth_header
      render json: { error: "Missing authentication" }, status: 401
      return
    end
    begin
      payload = Rails.application.message_verifier(:vibes_api).verify(auth_header)
      if payload['expires_at'] && Time.parse(payload['expires_at']) < Time.current
        render json: { error: "Token expired" }, status: 401 and return
      end
      @auth_payload = payload
    rescue => e
      Rails.logger.error "❌ Vibes API auth failed: #{e.message}"
      render json: { error: "Invalid authentication" }, status: 401
    end
  end
  
  def vibes_engine_root
    if Rails.env.development? && !ENV['FLY_APP_NAME']
      # Local development: use lib/engines/vibes
      Rails.root.join('lib', 'engines', 'vibes')
    else
      # Fly.io: use mounted volume
      Pathname.new('/mnt/data/vibes')
    end
  end
  
  def path_safe?(full_path)
    # Ensure the path is within the vibes engine directory
    vibes_root = vibes_engine_root.realpath rescue vibes_engine_root
    begin
      full_path.realpath.to_s.start_with?(vibes_root.to_s)
    rescue
      # If realpath fails, check if it would be within the directory
      full_path.to_s.start_with?(vibes_root.to_s)
    end
  end
  
  def collect_vibes_files(root_path, relative_path = "")
    files = []
    
    Dir.entries(root_path.join(relative_path)).each do |entry|
      next if entry.start_with?('.')
      
      full_path = root_path.join(relative_path, entry)
      relative_file_path = File.join(relative_path, entry).sub(/^\//, '')
      
      if full_path.directory?
        # Recursively collect files from subdirectories
        files.concat(collect_vibes_files(root_path, relative_file_path))
      elsif full_path.file? && editable_file?(entry)
        files << {
          path: relative_file_path,
          name: entry,
          type: 'file',
          size: full_path.size,
          last_modified: File.mtime(full_path).iso8601,
          extension: File.extname(entry)
        }
      end
    end
    
    files.sort_by { |f| f[:path] }
  rescue => e
    Rails.logger.error "❌ Error collecting vibes files: #{e.message}"
    []
  end
  
  def editable_file?(filename)
    # Only allow editing of certain file types for security
    allowed_extensions = %w[.rb .erb .yml .yaml .json .md .txt .css .scss .js .coffee]
    allowed_extensions.include?(File.extname(filename).downcase)
  end
  
  def create_git_commit_if_needed(message)
    vibes_root = vibes_engine_root
    return unless vibes_root.exist?
    
    Dir.chdir(vibes_root) do
      # Initialize git if not already done
      unless Dir.exist?('.git')
        system('git init')
        system('git config user.email "vibes@rubyonvibes.com"')
        system('git config user.name "Ruby on Vibes"')
      end
      
      # Add and commit changes
      system('git add .')
      system("git commit -m '#{message}' --allow-empty")
    end
  rescue => e
    Rails.logger.warn "⚠️  Git commit failed: #{e.message}"
  end
end
