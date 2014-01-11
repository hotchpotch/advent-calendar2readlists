
require 'readlists/anonymous'
require 'open-uri'
require 'nokogiri'

module ReadlistsAdventCalendar
  def factory(url)
    [Adventar, Qiita].each do |klass|
      if klass.const_get(:URL).match url
        return klass.new(url)
      end
    end
    nil
  end
  module_function :factory

  class Base
    attr_reader :url
    def initialize(url)
      @url = url
      @messages = []
    end

    def html
      @html ||= Nokogiri::HTML(open(url).read)
    end

    def puts(msg)
      Kernel.puts msg
      @messages << msg
    end

    def generate(&progress)
      readlists = Readlists::Anonymous.create

      puts "* Created anynymous readlists"
      puts "share-url: #{readlists.share_url}"
      puts "public-edit-url: #{readlists.public_edit_url}"

      readlists.title = self.title
      readlists.description = self.title

      progress.call([links.size, 0, @messages.clone])
      links.each_with_index do |url, index|
        retried = false
        begin
          puts "- Added: #{url}"
          readlists << url
        rescue Readlists::Anonymous::RequestError => e
          if retried
            puts "* 2nd error.. ignore #{url}"
          else
            puts "* Error.. retry"
            retried = true
            retry
          end
        end
        progress.call([links.size, index + 1, @messages.clone])
      end

      puts "* Created anynymous readlists"
      puts "share-url: #{readlists.share_url}"
      puts "public-edit-url: #{readlists.public_edit_url}"
      readlists
    end

    def links; end

    def title; end

    def description; end
  end

  class Adventar < Base
    URL = %r{\Ahttp://www.adventar.org/calendars/\d+}

    def links
      @links ||= html.css('a.mod-calendar-entryLink').map {|link| link.attr('href') }
    end

    def title
      @title ||= html.css('h2')[0].inner_text.strip
    end

    def description
      @description ||= html.css('.mod-calendarDescription')[0].inner_text.strip
    end
  end

  class Qiita < Base
    URL = %r{\Ahttp://qiita.com/advent-calendar/\d+/}

    def links
      unless @links
        @links = html.css('table .user-info .content a').map {|link|
          href = link.attr('href')
          href[0] == '/' ? "http://qiita.com#{href}" : href
        }
      end
      @links
    end

    def title
      @title ||= html.css('.page-title h1')[0].inner_text.strip
    end

    def description
      @description ||= html.css('meta[name=description]')[0].attr('content')
    end
  end
end
