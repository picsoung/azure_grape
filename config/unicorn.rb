user 'deployer', 'staff'

root = "/home/deployer/apps/grape/current"
 
working_directory root

shared_path = "/home/deployer/apps/grape/shared"
pid "#{root}/tmp/pids/unicorn.pid"
stderr_path "#{shared_path}/log/unicorn.log"
stdout_path "#{shared_path}/log/unicorn.log"

worker_processes 2;
timeout 30
preload_app true
listen "/tmp/unicorn.grape.sock"