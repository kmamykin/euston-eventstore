require 'database_cleaner'
require 'database_cleaner/cucumber'

DatabaseCleaner.orm = :mongoid
DatabaseCleaner.strategy = :truncation

Before do
  DatabaseCleaner.clean
end