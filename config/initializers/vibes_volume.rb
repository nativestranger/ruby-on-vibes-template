Rails.application.config.after_initialize do
  vibes_views = if Rails.env.production?
    '/mnt/data/vibes/app/views'
  else
    Rails.root.join('lib', 'engines', 'vibes', 'app', 'views').to_s
  end

  ActionController::Base.prepend_view_path(vibes_views)
end


