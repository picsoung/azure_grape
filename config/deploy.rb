require "bundler/capistrano"


set :application, "grape"
set :user, "deployer"
set :group, "staff"


set :scm, :git
set :repository, "git@github.com:picsoung/azure_grape.git"
set :branch, "master"
set :use_sudo, true


server "rubytest3scale.cloudapp.net", :web, :app, :db, primary: true


set :deploy_to, "/home/#{user}/apps/#{application}"
default_run_options[:pty] = true
ssh_options[:forward_agent] = true
ssh_options[:port] = 22


namespace :deploy do
    desc "Custom AceMoney deployment: stop."
    task :stop, :roles => :app do

        invoke_command "cd #{current_path};./script/ferret_server -e production stop"
        invoke_command "service thin stop"
    end

    desc "Custom AceMoney deployment: start."
    task :start, :roles => :app do

        invoke_command "cd #{current_path};./script/ferret_server -e production start"
        invoke_command "service thin start"
    end

    # Need to define this restart ALSO as 'cap deploy' uses it
    # (Gautam) I dont know how to call tasks within tasks.
    desc "Custom AceMoney deployment: restart."
    task :restart, :roles => :app do

        invoke_command "cd #{current_path};./script/ferret_server -e production stop"
        invoke_command "service thin stop"
        invoke_command "cd #{current_path};./script/ferret_server -e production start"
        invoke_command "service thin start"
    end
end