require "bundler/capistrano"
require 'capistrano/foreman'

set :application, "sentimentApi"
set :user, "azureuser"

set :scm, :git
set :repository, "git@github.com:picsoung/azure_grape.git"
set :branch, "master"
set :use_sudo, true

server "picsoung.cloudapp.net", :web, :app, :db, primary: true

set :deploy_to, "/home/#{user}/apps/#{application}"
default_run_options[:pty] = true
ssh_options[:forward_agent] = true
ssh_options[:port] = 22

namespace :deploy do
  set :foreman_sudo, 'sudo'                    # Set to `rvmsudo` if you're using RVM
  set :foreman_upstart_path, '/home/#{user}/apps/#{application}' # Set to `/etc/init/` if you don't have a sites folder
  set :foreman_options, {
    app: application,
    log: "#{shared_path}/log",
    user: user,
  }

  task :setup_config, roles: :app do
    sudo "ln -nfs #{current_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
    sudo "mkdir -p #{shared_path}/config"
  end
  after "deploy:setup", "deploy:setup_config"


  task :symlink_config, roles: :app do
    # Add database config here
  end
  after "deploy:finalize_update", "deploy:fix_permissions"
  after "deploy:finalize_update", "deploy:symlink_config"
end