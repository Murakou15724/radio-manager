class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
  end

  def create
    reset_session
    session[:authenticated] = true
    redirect_to root_path, notice: "ログインしました"
  end

  def destroy
    session[:authenticated] = nil
    redirect_to login_path, notice: "ログアウトしました"
  end
end