class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user
  
  private
  
  def authenticate_user
    unless session[:authenticated]
      redirect_to login_path, alert: "You need to log in to access this page"
    end
  end
end
