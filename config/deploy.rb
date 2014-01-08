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
  task :start, :roles => [:web, :app] do
    run "cd #{deploy_to}/current && nohup bundle exec thin start -C config/production_config.yml -R config.ru"
  end
 
  task :stop, :roles => [:web, :app] do
    run "cd #{deploy_to}/current && nohup bundle exec thin stop -C config/production_config.yml -R config.ru"
  end
 
  task :restart, :roles => [:web, :app] do
    deploy.stop
    deploy.start
  end
 
  # This will make sure that Capistrano doesn't try to run rake:migrate (this is not a Rails project!)
  task :cold do
    deploy.update
    deploy.start
  end
end