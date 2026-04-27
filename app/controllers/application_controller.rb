class ApplicationController < ActionController::Base
  before_action :require_login

  private

  def logged_in?
    session[:authenticated] == true
  end

  def require_login
    unless logged_in?
      redirect_to login_path
    end
  end
end
