
require 'sinatra'
require 'dalli'
require 'memcachier'
require 'securerandom'
require 'slim'
require 'readlists-advent-calendar'



class App < Sinatra::Base
  def self.cache
    @cache ||= Dalli::Client.new
  end

  get '/' do
    if url = params[:url]
      if rac = ReadlistsAdventCalendar.factory(url)
        uid = SecureRandom.hex(10)
        result = {
          finished: false,
          url: url,
        }
        self.class.cache.set(uid, result)
          puts 'hoge'
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
      end
    end
    slim :index
  end

  get '/u/:uid' do
    result = self.class.cache.get(params[:uid])
    if result
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
end
