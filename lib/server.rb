require 'sinatra'
require_relative 'repomate/base'
require_relative 'configuration'
require_relative 'packages'
require_relative 'pool'
require_relative 'repomate/component'
require_relative 'repomate/stage'
require_relative 'repomate/suite'

class Server < Sinatra::Base

  @config   = Configuration.new

  set :bind, @config.get[:server][:bind]
  set :port, @config.get[:server][:port]

  set :public_folder, File.expand_path('../server/public', __FILE__)
  set :views, File.expand_path('../server/views', __FILE__)
  set :static, true
  set :layout, true

  get '/' do
    redirect '/packages/squeeze/main'
  end

  get '/suites' do
    @suites = RepoMate::Suite.all
    erb :'suites'
  end

  get '/components' do
    @components = RepoMate::Component.all
    erb :'components'
  end

  get '/stages' do
    @stages = RepoMate::Stage.all
    erb :'stages'
  end

  get '/packages/:suitename/:component' do
    @pool      = Pool.new
    @suitename = params[:suitename]
    @component = params[:component]
    @packages  = []

    debfiles = File.join(@pool.pool_dir(@suitename, @component), "*.deb")

    Dir.glob(debfiles) do |source_fullname|
      package = Package.new(source_fullname, @suitename)

      basename    = package.controlfile['Package']
      version     = package.controlfile['Version']
      description = package.controlfile['Description']

      @packages.push({:basename => basename, :version => version, :description => description})
    end

    erb :'index'
  end

end

