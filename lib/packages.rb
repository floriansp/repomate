require 'yaml'
require 'tempfile'
require_relative 'configuration'

class Package

  attr_reader :newbasename, :controlfile

  def initialize(fullname, distname)
    @config   = Configuration.new
    @fullname = fullname
    @distname = distname
    @basename = File.basename(fullname)

    check_package

    @controlfile  = read_controlfile
    @name         = @controlfile['Package']
    @version      = @controlfile['Version']
    @architecture = @controlfile['Architecture']
    @newbasename  = "#{@name}-#{@version}_#{@architecture}.deb"

  end

  protected
  def check_package
    raise "file is not installed" unless File.exists?(@config.get[:file])

    unless `file --dereference #{@fullname}` =~ /Debian binary package/i
      puts "File does not exist or is not a Debian package!"
      false
    end
  end

  def read_controlfile
    gzbasename  = "control.tar.gz"
    basename    = "control"
    tmpdir      = File.expand_path "#{Dir.tmpdir}/#{Time.now.to_i}#{rand(1000)}/"
    gzfullname  = File.join(tmpdir, gzbasename)
    fullname    = File.join(tmpdir, basename)

    FileUtils.mkdir_p(tmpdir)
    begin
      raise "Could not untar" unless system "#{@config.get[:ar]} -p #{@fullname} #{gzbasename} > #{gzfullname}"
      raise Errno::ENOENT, "Package file does not exist" unless File.exists?(gzfullname)
      raise "Could not untar" unless system "#{@config.get[:tar]} xfz #{gzfullname} -C #{tmpdir}"
      YAML::load_file(fullname)
    ensure
      FileUtils.rm_rf(tmpdir)
    end
  end
end
