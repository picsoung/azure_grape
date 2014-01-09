APIs are platform agnostic, you can deploy them on any type of platforms. We've covered Heroku and Amazon deployments in before. Today we want to show you how to deploy an API on [Windows Azure](http://windowsazure.com). We will use Ruby [Grape gem](http://github.com/intridea/grape) to create the API interface, Nginx proxy, [Thin server](code.macournoyer.com/thin) and [Capistrano](https://github.com/capistrano/capistrano) to deploy using command line.

For the purpose of this tutorial you can use any Ruby based API running on Thin server. Or you can clone our [SentimentAPI](https://github.com/3scale/sentiment-api-example).

## Creating and configure Windows Azure VM

Let's get started by creating you Windows Azure account. For this tutorial you can use the [Free Trial option](http://www.windowsazure.com/en-us/pricing/free-trial/).
Once your Azure account is created, go to the [Dashboard](https://manage.windowsazure.com) on the Virtual Machines tab.  There, you will be guided to create your first VM.
In this example we will launch a VM using *Ubuntu Server 12.04 LTS*. Choose a name for your VM, set a password and a region. Then is going to  take a couple of minutes until your VM is ready.

As soon as your VM is ready you will be able to access it's own dashboard. On the dashboard you can monitor the activity (CPU, disk , network) of your VM, and upgrade it's size.

The VM comes with really few packages installed.  We need to access it to install other components.
Azure requires to create a *X509 certificate with a 2048-bit RSA keypair* to ssh into VMs.

To generate this type of key you can run the following command:
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout myPrivateKey.key -out myCert.pem
```

Once the key is create you can ssh to your VM

```
ssh -i myPrivateKey.key -p 22 username@servicename.cloudapp.net
```

Once in it the VM run the following commands to install all we need
```
sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt-get -y install ruby1.9.3 build-essential libsqlite3-dev nodejs git-core nginx
```
You can check that Ruby installation is complete by running
```
ruby -v
```
it should output something like *ruby 1.9.3p194 (2012-04-20 revision 35410) [x86_64-linux]*.

we also need to install `bundler` and `thin`:
```
sudo gem install bundler
sudo gem install thin
```

Now, we should have we need for now on the VM. Go back to the VM's dashboard and click on the *Endpoints* tab. There, add the `HTTP` endpoint on port 80, the fields should auto-filled.

To make sure it works, launch `nginx`

```
sudo service nginx start
```
and open in your browser the url corresponding to the DNS of your virtual machine (*.cloudapp.net).

You should see the message *"welcome to nginx!"*

If it works you can now stop `nginx` and delete the default website

```
sudo service nginx stop
sudo rm /etc/nginx/sites-enabled/default
```

## Configure your github repo

In this tutorial we use github to host our code. If you do not have a repo yet for your API, make sure to create one and host it on github.com. If you are not familiar with git and github you can check a great tutorial here (LINK TO BE FOUND).

To be able to use git on your VM and have access to your github repo you need to generate SSH key on your VM and add it to Github as explained [here](https://help.github.com/articles/generating-ssh-keys#platform-all).

We won't deal with github anymore.

## Configure your API

To deploy the API we use `Capistrano`. Capistrano is an automation tool, that will let you setup tasks for your deployments and let you execute them using command line interface.

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
upstream YOURAPINAME {
  server 127.0.0.1:8000;
}

server {
  listen 80;
  server_name VNDNSname live;
  root /home/USERNAME/apps/YOURAPINAME/current;
  access_log /home/USERNAME/apps/YOURAPINAME/current/log/thin.log;
  error_log /home/USERNAME/apps/YOURAPINAME/current/log/error.log;

  location / {
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;
    proxy_pass http://YOURAPINAME;
  }

  error_page 500 502 503 504 /500.html;
  client_max_body_size 4G;
  keepalive_timeout 10;
}

```
This conf file describe how nginx should behave when it receives request to your API.
In this conf file replace the following
`YOURAPINAME` with your actual API name
`USERNAME` with VM's username
`VNDNSname` with your .cloudapp.net url

When we run the `capify` command it generates two files, `Capfile` and `deploy.rb`. In `deploy.rb` you describe all the commands necessary to deploy your app.

In `/config` edit `deploy.rb` and replace the content by the following

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
ssh_options[:keys] = ["/PATH/TO/myPrivateKey.key"]


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
`VNDNSname` with your .cloudapp.net DNS
`YOURAPPLICATIONNAME` with your applicationame
`USERNAME` with the username used to login into the VM
`GITHUBUSERNAME` with your Github username
`REPO` with your Github repo name
`/PATH/TO` with the path to access the SSH key created before

This works well if we don't have any database in our API. If you do have a database you can comment the lines:
```ruby
task :cold do
    deploy.update
    deploy.start
  end
```

We also need to add a file `production_config.yml` in `/config` to configure the thin server

```yml
environment: production
chdir: /home/USERNAME/apps/YOURAPINAME/current/
address: 127.0.0.1
user: USERNAME
port: 8000
pid: /home/USERNAME/apps/YOURAPINAME/current/tmp/thin.pid
rackup: /home/USERNAME/apps/YOURAPINAME/current/config.ru
log: /home/USERNAME/apps/YOURAPINAME/current/log/thin.log
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

We are almost done :)

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

Your API should now be available on the url `MYAPI.cloudapp.net/path/to/ressources`
In the case you deploy the Sentiment API V2. `MYAPI.cloudapp.net/v2/words/hello.json`

You now have an API running on an Azure Linux instance.
Hope you enjoyed this tutorial.

Please let us know if you have any remarks or questions about it.

