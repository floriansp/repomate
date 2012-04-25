require 'yaml'
require 'tempfile'

class Package

  attr_reader :newbasename, :controlfile

  def initialize(fullname, distname)
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
    unless `file #{@fullname}` =~ /Debian binary package/i
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
    raise "Could not untar" unless system "ar -p #{@fullname} #{gzbasename} > #{gzfullname}"
    raise Errno::ENOENT, "Package file does not exist" unless File.exists?(gzfullname)
    raise "Could not untar" unless system "tar xfz #{gzfullname} -C #{tmpdir}"
    controlfile = YAML::load_file(fullname)
    FileUtils.rm_rf(tmpdir)
    controlfile
  end
end
