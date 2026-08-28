threads_count = ENV.fetch('RAILS_MAX_THREADS', 3).to_i
threads threads_count, threads_count

port ENV.fetch('PORT', 3000)
environment ENV.fetch('RAILS_ENV') { ENV.fetch('RACK_ENV', 'development') }

pidfile ENV.fetch('PIDFILE', 'tmp/pids/server.pid')

workers ENV.fetch('WEB_CONCURRENCY', 0).to_i
preload_app! if ENV.fetch('WEB_CONCURRENCY', 0).to_i > 1

plugin :tmp_restart
