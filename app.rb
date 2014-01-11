
require 'sinatra'
require 'dalli'
require 'memcachier'
require 'securerandom'
require 'slim'
require 'readlists-advent-calendar'
require "sinatra/json"


class App < Sinatra::Base
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
      url: url,
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

  post '/' do
    if url = @url = params[:url]
      if rac = ReadlistsAdventCalendar.factory(url)
        uid = async_generate_readlists(rac)
        redirect "/u/#{uid}"
      else
        # invalid url
        @error_msg = "URL '#{url}' is not supported."
      end
    end
    slim :index
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
