APIs are platform agnostic, you can deploy them on any type of platforms. We've covered Heroku and Amazon deployments in before. Today we want to show you how to deploy an API on Windows Azure. We will use Ruby Grape gem to create the API interface, Nginx proxy, Thin server and Capistrano on deploy on command line.

For the purpose of this tutorial you can use any Ruby based API running on Thin server. Or you can clone our SentimalAPI (here).

Creating and configure Windows Azure VM

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
```sudo gem install bundler
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
Configure your github repo

In this tutorial we use github to host our code. If you have not a repo for your API, make sure to create one and host it on github.com. If you are not familiar with git and github you can check a great tutorial here (LINK TO BE FOUND).

To be able to use git on your VM and have access to your github repo you need to generate SSH keyson your VM and add it to Github as explained here.

We won't deal with github anymore.

Configure your API

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

Copy and paste the content of nginx.conf into /config.

And replace grapeapi by your API name and azureuser by the user on your VM.

in /config edit deploy.rb and replace it with the content by the following

 
