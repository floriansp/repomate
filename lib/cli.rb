require_relative 'packages'
require_relative 'pool'

class Cli
  def initialize
    @pool = Pool.new
  end

  def list_packages(suitename=nil)
    if suitename.nil?
      @pool.structure.each do |suitename, components|
        components.each do |component|
          list_packages_by_suite(suitename, component)
        end
      end
    else
      list_packages_by_suite(suitename, component)
    end
  end

  def list_packages_by_suite(suitename, component)
    debfiles = File.join(@pool.pool_dir(suitename, component), "*.deb")
    Dir.glob(debfiles) do |source_fullname|
      package = Package.new(source_fullname, suitename)

      basename    = package.controlfile['Package']
      version     = package.controlfile['Version']
      description = package.controlfile['Description']

      printf "%-50s%-20s%s\n", basename, version, "#{suitename}/#{component}"
    end
  end
end
