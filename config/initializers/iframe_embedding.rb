# Configure iframe embedding for Ruby on Vibes Live Preview
# Set ALLOW_IFRAME_EMBEDDING=true to enable iframe embedding

if ENV['ALLOW_IFRAME_EMBEDDING'] == 'true'
  # Simple and reliable approach: Add middleware to remove X-Frame-Options
  Rails.application.config.middleware.use(Class.new do
    def initialize(app)
      @app = app
    end
    
    def call(env)
      status, headers, response = @app.call(env)
      # Remove X-Frame-Options to allow iframe embedding
      headers.delete('X-Frame-Options')
      # Alternatively, set to ALLOWALL if needed
      # headers['X-Frame-Options'] = 'ALLOWALL'
      [status, headers, response]
    end
  end)
  
  Rails.logger.info "🖼️  Iframe embedding enabled for Ruby on Vibes Live Preview"
else
  Rails.logger.info "🔒 Iframe embedding disabled (set ALLOW_IFRAME_EMBEDDING=true to enable)"
end
