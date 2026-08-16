Rails.application.routes.draw do
  ActiveAdmin.routes(self)

  root to: redirect('/admin/') # if Routing::Admin.present?
end
