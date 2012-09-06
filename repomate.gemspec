Gem::Specification.new do |spec|
  spec.license                = 'MIT'
  spec.name                   = 'repomate'
  spec.version                = '0.3.0'
  spec.files                  = Dir["bin/*"] + Dir["lib/**/*"]
  spec.summary                = 'A tool to manage Debian repositories'
  spec.description            = 'A tool to manage Debian repositories'
  spec.executables            = ['repomate']
  spec.required_ruby_version  = '> 1.9'

  spec.authors                = ['Florian Speidel', 'Michael Ehrenreich']
  spec.email                  = ['flo@doobie.cc', 'michael.ehrenreich@me.com']
  spec.homepage               = 'https://github.com/floriansp/repomate'

  if spec.respond_to? :specification_version then
    spec.specification_version = 3
    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      spec.add_runtime_dependency(%q<slop>, ["~> 3.0.4"])
      spec.add_runtime_dependency(%q<gpgme>, ["~> 2.0.0"])
      spec.add_runtime_dependency(%q<sqlite3>, ["~> 1.3.6"])
    else
      spec.add_dependency(%q<slop>, ["~> 3.0.4"])
      spec.add_dependency(%q<gpgme>, ["~> 2.0.0"])
      spec.add_dependency(%q<sqlite3>, ["~> 1.3.6"])
    end
  else
    spec.add_dependency(%q<slop>, ["~> 3.0.4"])
    spec.add_dependency(%q<gpgme>, ["~> 2.0.0"])
    spec.add_dependency(%q<sqlite3>, ["~> 1.3.6"])
  end
end

