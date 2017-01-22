#!/usr/bin/env puma
directory '{{ application_path }}/current'
rackup '{{ application_path }}/current/config.ru'
environment 'production'

daemonize true

pidfile '{{ shared_path }}/tmp/pids/puma.pid'
state_path '{{ shared_path }}/tmp/pids/puma.state'
stdout_redirect '{{ shared_path }}/log/puma_access.log', '{{ shared_path }}/log/puma_error.log', true

# The default is 0, 16
threads 1, 6

bind 'unix://{{ shared_path }}/tmp/sockets/puma.{{ name_app }}.sock'

workers 2

preload_app!

on_restart do
  puts 'Refreshing Gemfile'
  ENV["BUNDLE_GEMFILE"] = '{{ application_path }}/current/Gemfile'
end

on_worker_boot do
  ActiveSupport.on_load(:active_record) do
    ActiveRecord::Base.establish_connection
  end
end
