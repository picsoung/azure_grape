require "bundler/capistrano"


set :application, "grapeapi"
set :user,"azureuser"
#set :group, "staff"


set :scm, :git
set :repository, "git@github.com:picsoung/azure_grape.git"
set :branch, "master"
set :use_sudo, false


server "ruby3scale.cloudapp.net", :web, :app, :db, primary: true


set :deploy_to, "/home/#{user}/apps/#{application}"
default_run_options[:pty] = true

ssh_options[:forward_agent] = false
ssh_options[:port] = 22
ssh_options[:keys] = ["/Users/picsoung/Documents/Dev/3scale/add-on/azure/myPrivateKey.key"]


namespace :deploy do
  desc "Fix permissions"
  task :fix_permissions, :roles => [ :app, :db, :web ] do
    run "chmod +x #{release_path}/config/unicorn_init.sh"
  end


  %w[start stop restart].each do |command|
    desc "#{command} unicorn server"
    task command, roles: :app, except: {no_release: true} do
      run "service unicorn_#{application} #{command}"
    end
  end


  task :setup_config, roles: :app do
    sudo "ln -nfs #{current_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
    sudo "ln -nfs #{current_path}/config/unicorn_init.sh /etc/init.d/unicorn_#{application}"
    sudo "mkdir -p #{shared_path}/config"
  end
  after "deploy:setup", "deploy:setup_config"


  task :symlink_config, roles: :app do
    # Add database config here
  end
  after "deploy:finalize_update", "deploy:fix_permissions"
  after "deploy:finalize_update", "deploy:symlink_config"

  desc "Override deploy:cold to NOT run migrations - there's no database"
  task :cold do
    update
    start
  end
end