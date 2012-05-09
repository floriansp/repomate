require_relative 'configuration'
require_relative 'database'
require 'tempfile'

# RepoMate module
module RepoMate

  # Class for reading debian packages
  class Package

    attr_reader :name, :basename, :newbasename, :controlfile, :architecture, :version

    # Init
    def initialize(fullname, suitename, component)
      @config     = Configuration.new
      @fullname   = fullname
      @suitename  = suitename
      @component  = component
      @basename   = File.basename(fullname)
      @packagesdb = File.join(@config.get[:rootdir], @config.get[:checksumsdb])
      @db         = Database.new(@packagesdb)

      check_package
      create_db

      @controlfile  = read_controlfile
      @name         = @controlfile['Package']
      @version      = @controlfile['Version']
      @architecture = @controlfile['Architecture']
      @newbasename  = "#{@name}-#{@version}_#{@architecture}.deb"
    end

    # Get's the location of the checksum logfile
    def checksumlog
      File.join(@config.get[:logdir], @config.get[:checksumlog])
    end

    def create_db
      sql = "create table if not exists packages ( basename varchar2(70), md5 varchar(32), sha1 varchar(40), sha265 varchar(64) )"
      @db.query(sql)
    end

    def checksums
      basename  = File.basename(@fullname)
      mtime     = File.mtime(@fullname)
      result    = nil

      @db.query("select * from packages where basename = '#{basename}'").each do |row|
        result = row

        # puts "Hit: #{basename} #{result}"
      end

      if result.nil?
        #puts "Ins: #{basename}"

        md5      = Digest::MD5.file(@fullname).to_s
        sha1     = Digest::SHA1.file(@fullname).to_s
        sha256   = Digest::SHA256.new(256).file(@fullname).to_s
        @db.query("insert into packages values ( '#{basename}', '#{md5}', '#{sha1}', '#{sha256}' )")
      end
      result
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
            line =~ %r{(.*):\s(.*)}
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
