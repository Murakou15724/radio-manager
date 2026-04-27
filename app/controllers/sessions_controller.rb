class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
  end

  def create
    if params[:password] == ENV["APP_PASSWORD"]
      session[:authenticated] = true
      redirect_to root_path, notice: "ログインしました"
    else
      flash.now[:alert] = "パスワードが間違っています"
      render :new
    end
  end

  def destroy
    session[:authenticated] = nil
    redirect_to login_path, notice: "ログアウトしました"
  end
end