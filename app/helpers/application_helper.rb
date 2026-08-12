module ApplicationHelper
  def app_version
    Rails.application.config.x.app_version
  end
end
