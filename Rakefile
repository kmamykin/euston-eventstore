require 'bundler'
Bundler.setup
Bundler::GemHelper.install_tasks

$:.unshift 'lib'

require 'ap'
require 'rake'
require 'eventstore'

Dir[File.join(File.dirname(__FILE__), 'lib/tasks/*.rake')].each { |rake| load rake }

task :clobber do
  rm_rf 'pkg'
  rm 'mongo.log'
end

task :default => :spec
