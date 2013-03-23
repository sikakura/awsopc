Ec2Service::Application.routes.draw do

  get "menus/index"

  resources :auths

  get "auths/index"

  root :to => 'home#index'

  devise_for :users
#  get 'servers', :to => 'servers#index', :as => :user_root
  get 'menus/index', :to => 'menus#index', :as => :user_root

  resources :servers

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'
  

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
