module Vibes
  class ApplicationController < ::ApplicationController
    # Inherit from main app's ApplicationController to get:
    # - Devise helpers (user_signed_in?, current_user, etc.)
    # - All other main app functionality
    
    # Include main app route helpers explicitly
    include Rails.application.routes.url_helpers
    
    # Make route helpers available in views too
    helper Rails.application.routes.url_helpers
    
    # Engine-specific before_actions can go here if needed
    # before_action :some_engine_specific_method
    
    protected
    
    # Override this method if you need engine-specific authentication logic
    # def authenticate_user!
    #   super
    # end
  end
end
