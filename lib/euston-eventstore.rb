require 'active_support/concern'
require 'hash-keys'
require 'require_all'

require_rel 'euston-eventstore'

Json = JSON if defined?(JSON) && !defined?(Json)
