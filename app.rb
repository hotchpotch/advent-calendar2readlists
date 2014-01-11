
require 'sinatra'
require 'dalli'
require 'memcachier'
require 'securerandom'
require 'slim'
require 'readlists-advent-calendar'
require 'sinatra/json'
require 'rack/protection'

class App < Sinatra::Base
  enable :sessions
  use Rack::Protection
  helpers Sinatra::JSON
  configure :development do
    require 'sinatra/reloader'
    register Sinatra::Reloader
  end

  def self.cache
    @cache ||= Dalli::Client.new
  end

  def async_generate_readlists(rac)
    uid = SecureRandom.hex(10)
    result = {
      finished: false,
      url: rac.url,
    }
    self.class.cache.set(uid, result)
    EM::defer do
      begin
        readlists = rac.generate {|total, current, messages|
          result[:finished] = :generating
          result[:progress] = [total, current, messages]
          self.class.cache.set(uid, result)
        }
        result[:finished] = :sucesssed
        result[:readlists] = readlists
        self.class.cache.set(uid, result)
      rescue => e
        puts "generate error: #{e}"
        p e.backtrace.join("\n")
        result[:finished] = :failed
        self.class.cache.set(uid, result)
      end
    end
    uid
  end

  error 404 do
    'Not Found.'
  end

  get '/' do
    slim :index
  end

  post '/g' do
    if params[:url] && (rac = ReadlistsAdventCalendar.factory(params[:url].to_s))
      uid = async_generate_readlists(rac)
      redirect "/u/#{uid}"
    else
      # invalid url
      @error_msg = "URL '#{params[:url]}' is not supported."
    end
    slim :index
  end

  get '/u/' do
    redirect '/'
  end

  get '/u/:uid' do
    @uid = params[:uid]
    result = @result = self.class.cache.get(@uid)
    if result
      case result[:finished]
      when :sucesssed, :failed
        @readlists = result[:readlists]
        slim :result
      else
        slim :check
      end
    else
      404
    end
  end

  get '/u/check/:uid' do
    result = self.class.cache.get(params[:uid])
    case result[:finished]
    when :sucesssed, :failed, :generating
      json result
    else
      404
    end
  end
end
