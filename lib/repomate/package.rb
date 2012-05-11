require 'digest/md5'
require 'digest/sha1'
require 'digest/sha2'
require 'tempfile'
require 'date'
require 'time'

# RepoMate module
module RepoMate

  # Class for reading debian packages
  class Package

    attr_reader :name, :basename, :newbasename, :controlfile, :architecture, :version, :suitename, :component, :fullname

    # Init
    def initialize(fullname, suitename, component)
      @fullname   = fullname
      @suitename  = suitename
      @component  = component
      @basename   = File.basename(fullname)
      @mtime      = File.mtime(fullname)
      @pkgdbfile  = File.join(Cfg.rootdir, "packages.db")
      @pkgdb      = Database.new(@pkgdbfile)

      check_package
      create_table

      @controlfile  = read_controlfile
      @name         = @controlfile['Package']
      @version      = @controlfile['Version']
      @architecture = @controlfile['Architecture']
      @newbasename  = "#{@name}-#{@version}_#{@architecture}.deb"
    end

    # Create the package table
    def create_table
      sql = "create table if not exists checksums (
              date varchar(25),
              basename varchar(70),
              mtime varchar(25),
              md5 varchar(32),
              sha1 varchar(40),
              sha256 varchar(64)
      )"
      @pkgdb.query(sql)
    end

    # Gets checksums for the given package
    def get_checksums
      result = []

      @pkgdb.query("select md5, sha1, sha256 from checksums where basename = '#{@basename}' and mtime = '#{@mtime.iso8601}'").each do |row|
        result = row
        # puts "Hit: #{@basename} #{result}"
      end
      result
    end

    # Creates the checksums for a package
    def create_checksums
      # puts "Ins: #{@basename}"
      now      = DateTime.now
      md5      = Digest::MD5.file(@fullname).to_s
      sha1     = Digest::SHA1.file(@fullname).to_s
      sha256   = Digest::SHA256.new(256).file(@fullname).to_s
      @pkgdb.query("insert into checksums values ( '#{now}', '#{@basename}', '#{@mtime.iso8601}', '#{md5}', '#{sha1}', '#{sha256}' )")
    end

    # Gets checksums for the given package
    def delete_checksums
      # puts "Del: #{@basename}"
      @pkgdb.query("delete from checksums where basename = '#{@basename}'")
    end

    protected

    # Checks if the given package is a debian package
    def check_package
      unless `file --dereference #{@fullname}` =~ /Debian binary package/i
        puts "File does not exist or is not a Debian package!"
        false
      end
    end

    # Extracts the controlfile and returns is
    def read_controlfile
      gzbasename  = "control.tar.gz"
      basename    = "control"
      tmpdir      = File.expand_path "#{Dir.tmpdir}/#{Time.now.to_i}#{rand(1000)}/"
      gzfullname  = File.join(tmpdir, gzbasename)
      fullname    = File.join(tmpdir, basename)

      controlfile = {}

      FileUtils.mkdir_p(tmpdir)

      begin
        raise "Could not untar" unless system "ar -p #{@fullname} #{gzbasename} > #{gzfullname}"
        raise Errno::ENOENT, "Package file does not exist" unless File.exists?(gzfullname)
        raise "Could not untar" unless system "tar xfz #{gzfullname} -C #{tmpdir}"

        File.open(fullname) do |file|
          while(line = file.gets)
            line =~ %r{([a-zA-Z]+):\s(.*)}
            controlfile[$1] = $2
          end
        end
      ensure
        FileUtils.rm_rf(tmpdir)
      end
      controlfile
    end
  end
end

