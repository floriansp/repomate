require 'sqlite3'

# RepoMate module
module RepoMate

  # Class for the database
  class Database

    # Init
    def initialize(dbfile)
      @db         = SQLite3::Database.new(dbfile)
      @basename   = File.basename(dbfile)
    end

    # Checks if the database file already exists
    def exists?
      File.exists?(@dbfile)
    end

    # Executes a query
    def query(sql)
      @db.execute(sql)
    end

    # Deletes a categories directory
    def destroy
      FileUtils.rm_r(@dbfile) if exists?
    end
  end
end

