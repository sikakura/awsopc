class MenusController < ApplicationController
  before_filter :authenticate_user!  

  def index
  
    @unregistered = false
    @auths = Auth.where(:user_id => current_user)
    @unregistered = true if @auths.count == 0

  end
end
