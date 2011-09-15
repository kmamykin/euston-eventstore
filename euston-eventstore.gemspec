Gem::Specification.new do |s|
  s.name        = 'euston-eventstore'
  s.version     = '1.0.2'
  s.date        = '2011-09-15'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Lee Henson', 'Guy Boertje']
  s.email       = ['lee.m.henson@gmail.com', 'guyboertje@gmail.com']
  s.summary     = %q{Event store for use with Euston.}
  s.description = "Ruby port for Jonathan Oliver's EventStore. See https://github.com/joliver/EventStore for details."
  s.homepage    = 'http://github.com/leemhenson/euston-eventstore'
  # = MANIFEST =
  s.files = %w[
    Gemfile
    Gemfile.lock
    Rakefile
    euston-eventstore.gemspec
    lib/euston-eventstore.rb
    lib/euston-eventstore/commit.rb
    lib/euston-eventstore/constants.rb
    lib/euston-eventstore/dispatcher/asynchronous_dispatcher.rb
    lib/euston-eventstore/dispatcher/null_dispatcher.rb
    lib/euston-eventstore/dispatcher/synchronous_dispatcher.rb
    lib/euston-eventstore/errors.rb
    lib/euston-eventstore/event_message.rb
    lib/euston-eventstore/optimistic_event_store.rb
    lib/euston-eventstore/optimistic_event_stream.rb
    lib/euston-eventstore/persistence/mongodb/mongo_commit.rb
    lib/euston-eventstore/persistence/mongodb/mongo_commit_id.rb
    lib/euston-eventstore/persistence/mongodb/mongo_config.rb
    lib/euston-eventstore/persistence/mongodb/mongo_event_message.rb
    lib/euston-eventstore/persistence/mongodb/mongo_persistence_engine.rb
    lib/euston-eventstore/persistence/mongodb/mongo_persistence_factory.rb
    lib/euston-eventstore/persistence/mongodb/mongo_snapshot.rb
    lib/euston-eventstore/persistence/mongodb/mongo_stream_head.rb
    lib/euston-eventstore/persistence/stream_head.rb
    lib/euston-eventstore/snapshot.rb
    lib/euston-eventstore/version.rb
    spec/event_store/dispatcher/asynchronous_dispatcher_spec.rb
    spec/event_store/dispatcher/synchronous_dispatcher_spec.rb
    spec/event_store/optimistic_event_store_spec.rb
    spec/event_store/optimistic_event_stream_spec.rb
    spec/event_store/persistence/mongodb_spec.rb
    spec/event_store/serialization/simple_message.rb
    spec/spec_helper.rb
    spec/support/array_enumeration_counter.rb
  ]
  # = MANIFEST =

  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }

  s.add_dependency 'activesupport',             '~> 3.0.9'
  s.add_dependency 'hash-keys',                 '~> 1.0.0'
  s.add_dependency 'require_all',               '~> 1.2.0'
  s.add_development_dependency 'awesome_print', '~> 0.4.0'
  s.add_development_dependency 'fuubar',        '~> 0.0.0'
  s.add_development_dependency 'rspec',         '~> 2.6.0'
end