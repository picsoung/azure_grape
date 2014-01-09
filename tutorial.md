APIs are platform agnostic, you can deploy them on any type of platforms. We've covered Heroku and Amazon deployments in before. Today we want to show you how to deploy an API on Windows Azure. We will use Ruby Grape gem to create the API interface, Nginx proxy, Thin server and Capistrano on deploy on command line.

For the purpose of this tutorial you can use any Ruby based API running on Thin server. Or you can clone our SentimalAPI (here).

## Creating and configure Windows Azure VM

Let's get started by creating you Windows Azure account. For this tutorial you can use the Free Trial option (http://www.windowsazure.com/en-us/pricing/free-trial/).
Once your Azure account is created, go to the Dashboard on the Virtual Machines tab.  There you will be guided to create your first VM.
In this example we will launch a VM using Ubuntu Server 12.04 LTS. Choose a name for your VM, set a password and a region. It's gonna take a couple of minutes until your VM is ready.

As soon as your VM is ready you will be able to access it's dashboard. On the dashboard you can monitor the activity (CPU, disk , network) of your VM, and upgrade it's size.

The VM comes with really few packages installed.  We need to access it to install other components.
Azure requires to create a X509 certificate with a 2048-bit RSA keypair to ssh into VMs.

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout myPrivateKey.key -out myCert.pem
```

Once the key is create you ssh to your VM

```
ssh -i myPrivateKey.key -p 22 username@servicename.cloudapp.net
```

Once in it run the following commands to install all we need
```
sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt-get -y install ruby1.9.3 build-essential libsqlite3-dev nodejs git-core nginx
```
You can check that ruby installation is complete by running
```
ruby -v
```
it should output something like ruby 1.9.3p194 (2012-04-20 revision 35410) [x86_64-linux].

we also need to install bundler and thin server
```
sudo gem install bundler
sudo gem install thin
```

We should have we need for now on the VM. Go back to the VM's dashboard and click on the Endpoints tab. There, add the HTTP endpoint on port 80, the fields should auto-filled.

To make sure it works, launch nginx

```
sudo service nginx start
```
and open in your browser the url corresponding to the DNS of your virtual machine (*.cloudapp.net).

You should see the message "welcome to nginx!"

If it works you can now stop nginx and delete the default website

```
sudo service nginx stop
sudo rm /etc/nginx/sites-enabled/default
```

## Configure your github repo

In this tutorial we use github to host our code. If you have not a repo for your API, make sure to create one and host it on github.com. If you are not familiar with git and github you can check a great tutorial here (LINK TO BE FOUND).

To be able to use git on your VM and have access to your github repo you need to generate SSH keyson your VM and add it to Github as explained here.

We won't deal with github anymore.

## Configure your API

To deploy the API we use Capistrano. Capistrano is an automation tool, that will setup tasks for your deployments and let you execute them using command line interface.

To install Capistrano add this line to your Gemfile

```
gem 'capistrano'
```

Run the following command to install the new gems and setup Capistrano

```
bundle
capify .
```

Copy and paste the content of `nginx.conf` into `/config`.

```conf
upstream grapeapi {
  server 127.0.0.1:8000;
}

server {
  listen 80;
  server_name ruby3scale.cloudapp.net live;
  root /home/azureuser/apps/grapeapi/current;
  access_log /home/azureuser/apps/grapeapi/current/log/thin.log;
  error_log /home/azureuser/apps/grapeapi/current/log/error.log;

  location / {
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;
    proxy_pass http://grapeapi;
  }

  error_page 500 502 503 504 /500.html;
  client_max_body_size 4G;
  keepalive_timeout 10;
}

```

And replace `grapeapi` by your API name and `azureuser` by the user on your VM.

in `/config` edit `deploy.rb` and replace it with the content by the following

```ruby
require "bundler/capistrano"

set :application, "YOURAPPLICATIONNAME"
set :user,"USERNAME"

set :scm, :git
set :repository, "git@github.com:GITHUBUSERNAME/REPO.git"
set :branch, "master"
set :use_sudo, false

server "VNDNSname", :web, :app, :db, primary: true

set :deploy_to, "/home/#{user}/apps/#{application}"
default_run_options[:pty] = true
ssh_options[:forward_agent] = false
ssh_options[:port] = 22
ssh_options[:keys] = ["/path/to/myPrivateKey.key"]


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

  task :setup_config, roles: :app do
    sudo "ln -nfs #{current_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
      sudo "mkdir -p #{shared_path}/config"
  end
  after "deploy:setup", "deploy:setup_config"
 
  # This will make sure that Capistrano doesn't try to run rake:migrate (this is not a Rails project!)
  task :cold do
    deploy.update
    deploy.start
  end
end
 
```
In above text, replace the following:
`VNDNSname` to your .cloudapp.net DNS
`YOURAPPLICATIONNAME` to your applicationame
`USERNAME` to the username used to login into the VM
`GITHUBUSERNAME` to your Github username
`REPO` to your Github repo name

We also need to add a file `production_config.yml` in `/config` to configure the thin server

```yml
environment: production
chdir: /home/azureuser/apps/grapeapi/current/
address: 127.0.0.1
user: azureuser
port: 8000
pid: /home/azureuser/apps/grapeapi/current/tmp/thin.pid
rackup: /home/azureuser/apps/grapeapi/current/config.ru
log: /home/azureuser/apps/grapeapi/current/log/thin.log
max_conns: 1024
timeout: 30
max_persistent_conns: 512
daemonize: true
```
Again, change usernames and paths accordingly.

Commit the changes on the project and upload them on Github

```sh
git add .
git commit -m "adding config files"
git push
```

## Deploy

For your local development machine, run the following command to setup the remote Azure VM:

```sh
cap deploy:setup
```
You should not be prompted for password if the path to your ssh key is correct.
Capistrano will connect to your VM and create an `apps` directory under the `home` directory of the user account.

Now, you can deploy your API to the VM and launch thin server using the command:

``` cap deploy:cold ```

In your VM, restart nginx. 
```
sudo service nginx stop
sudo service nginx start
```

Your API should now be available on the url MYAPI.cloudapp.net/path/to/ressources
In the case you deploy the Sentiment API V2. MYAPI.cloudapp.net/v2/words/hello.json

You now have an API running on an Azure Linux instance.
Hope you enjoyed this tutorial.

Please let us know if you have any remarks or questions about it.

