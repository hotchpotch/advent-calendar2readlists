
require 'sinatra'
require 'dalli'
require 'memcachier'
require 'securerandom'
require 'sinatra/twitter-bootstrap'
require 'haml'

class App < Sinatra::Base
  register Sinatra::Twitter::Bootstrap::Assets

  def self.cache
    @cache ||= Dalli::Client.new
  end

  get '/' do
    if params[:url]
      # validate
      uid = SecureRandom.hex(10)
      self.class.cache.set(uid, false)
      EM::defer do
        sleep 10
        self.class.cache.set(uid, true)
      end
      redirect "/u/#{uid}"
    end
    haml :index
  end

  get '/u/:uid' do
    self.class.cache.get(params[:uid]).to_s
  end
end
