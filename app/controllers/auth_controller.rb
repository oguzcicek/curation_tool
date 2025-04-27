class AuthController < ApplicationController
  skip_before_action :authenticate_user, only: [:login, :authenticate]
  
  def login
    redirect_to root_path if session[:authenticated]
  end
  
  def authenticate
    if params[:username] == ENV.fetch('APP_USERNAME', 'eliteadmin') && 
       params[:password] == ENV.fetch('APP_PASSWORD', 'xxx666Eliteauto')
      session[:authenticated] = true
      redirect_to root_path, notice: "Successfully logged in"
    else
      flash.now[:alert] = "Invalid username or password"
      render :login
    end
  end
  
  def logout
    session[:authenticated] = nil
    redirect_to login_path, notice: "You have been logged out"
  end
end 