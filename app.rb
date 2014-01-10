
require 'sinatra'
require 'dalli'
require 'memcachier'
require 'securerandom'
require 'slim'
require 'readlists-advent-calendar'
require 'sinatra/reloader'

class App < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  def self.cache
    @cache ||= Dalli::Client.new
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
        uid = SecureRandom.hex(10)
        result = {
          finished: false,
          url: url,
        }
        self.class.cache.set(uid, result)
        EM::defer do
          puts 'start!'
          begin
            readlists = rac.generate
            result[:finished] = :sucesssed
            result[:readlists] = readlists
            self.class.cache.set(uid, result)
          rescue
            result[:finished] = :failed
            self.class.cache.set(uid, result)
          end
        end
        redirect "/u/#{uid}"
      else
        # invalid url
        @error_msg = "URL(#{url}) is not support."
      end
    end
    slim :index
  end

  get '/u/:uid' do
    result = @result = self.class.cache.get(params[:uid])
    if result
      if result[:finished]
        @readlists = result[:readlists]
        slim :result
      else
        slim :u
      end
    else
      404
    end
  end

  get '/u/check/:uid' do
    result = self.class.cache.get(params[:uid])
    case result[:finished]
    when :sucesssed
      # memo: embed iframe url
      readlists = result[:readlists]
      result.inspect + "share-url: #{readlists.share_url}" + "public-edit-url: #{readlists.public_edit_url}"
    when :failed
      result.inspect
    when false
      'wait...'
    end
  end
end
