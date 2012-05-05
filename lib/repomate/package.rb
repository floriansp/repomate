require 'yaml'
require 'tempfile'

# RepoMate module
module RepoMate

  # Class for reading debian packages
  class Package

    attr_reader :newbasename, :controlfile, :architecture, :suitename, :component, :version, :name

    # Init
    def initialize(fullname, suitename, component)
      @fullname  = fullname
      @suitename = suitename
      @component = component
      @basename  = File.basename(fullname)

      check_package

      @controlfile  = read_controlfile
      @name         = @controlfile['Package']
      @version      = @controlfile['Version']
      @architecture = @controlfile['Architecture']
      @newbasename  = "#{@name}-#{@version}_#{@architecture}.deb"
    end

    protected

    # Checks if the given package is a debian package
    def check_package
      #p @fullname
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

      FileUtils.mkdir_p(tmpdir)
      begin
        raise "Could not untar" unless system "ar -p #{@fullname} #{gzbasename} > #{gzfullname}"
        raise Errno::ENOENT, "Package file does not exist" unless File.exists?(gzfullname)
        raise "Could not untar" unless system "tar xfz #{gzfullname} -C #{tmpdir}"
        YAML::load_file(fullname)
      ensure
        FileUtils.rm_rf(tmpdir)
      end
    end
  end
end
