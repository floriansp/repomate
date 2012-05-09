require_relative 'configuration'
require 'sqlite3'

# RepoMate module
module RepoMate

  # Class for the database
  class Database

    # Init
    def initialize(fullname)
      @fullname   = fullname
      @config     = Configuration.new
      @dbfile     = File.join(@config.get[:rootdir], @config.get[:repomatedb])
      @db         = SQLite3::Database.new(@dbfile)
      @basename   = File.basename(@fullname)
    end

    # Checks if the database file already exists
    def exists?
      File.exists?(@fullname)
    end

    # Executes a query
    def query(sql)
      @db.execute(sql)
    end

    # Deletes a categories directory
    def destroy
      FileUtils.rm_r(@fullname) if exists?
    end
  end
end
