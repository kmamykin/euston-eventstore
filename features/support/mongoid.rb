Mongoid.configure do |config|
  config.autocreate_indexes = false
  config.logger = Logger.new('mongo.log')
  config.master = Mongo::Connection.new('localhost', 27017, :logger => config.logger).db('protean')
  config.persist_in_safe_mode = true
  config.use_utc = true
end