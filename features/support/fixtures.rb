# Gives step definitions the same users(:dengle) style accessors the RSpec
# suite gets, backed by the same spec/fixtures data.
#
# Replaces the hand-rolled FixtureAccess module that used the removed
# `Fixtures` constant and Rails 3 fixture caching internals.
module FixtureAccess
  PATH = Rails.root.join('spec/fixtures')
  TABLES = Dir[PATH.join('*.yml')].map { |file| File.basename(file, '.yml') }.sort.freeze

  class << self
    attr_reader :sets

    def load!
      ActiveRecord::FixtureSet.reset_cache
      @sets = ActiveRecord::FixtureSet
              .create_fixtures(PATH, TABLES)
              .index_by(&:name)
    end

    def find(table, label)
      set = sets[table.to_s] or raise("No fixtures loaded for table '#{table}'")
      fixture = set.fixtures[label.to_s] or
        raise("No fixture with name '#{label}' found for table '#{table}'")
      fixture.find
    end
  end

  TABLES.each do |table|
    define_method(table) do |*labels|
      records = labels.map { |label| FixtureAccess.find(table, label) }
      records.size == 1 ? records.first : records
    end
  end

  # The database id Rails assigns to a fixture label.
  def fixture(label)
    ActiveRecord::FixtureSet.identify(label)
  end
end

World(FixtureAccess)

Before do
  DatabaseCleaner.clean
  FixtureAccess.load!
end
