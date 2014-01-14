require 'readlists/anonymous'
require 'open-uri'
require 'nokogiri'
require 'json'

module ReadlistsAdventCalendar
  def factory(url)
    [Adventar, Qiita, Atnd].each do |klass|
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

    def puts(msg)
      Kernel.puts msg
      @messages << msg
    end

    def html
      @html ||= Nokogiri::HTML(open(url).read)
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
    URL = %r{\Ahttps?://www\.adventar\.org/calendars/\d+}

    def json
      @json ||= JSON.parse(open("#{url}.json").read)
    end

    def links
      @links ||= json["entries"].map {|entry| entry["url"] }
    end

    def title
      @title ||= json["title"]
    end

    def description
      @description ||= json["description"]
    end
  end

  class Qiita < Base
    URL = %r{\Ahttps?://qiita\.com/advent-calendar/\d+/}

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

  class Atnd < Base
    URL = %r{\Ahttps?://atnd\.org/events/\d+}

    def links
      unless @links
        @links = html.css('#post-body table a').map {|link|
          href = link.attr('href').chomp
        }.uniq.select {|url|
          case url
          when %r{\Ahttps?://twitter\.com/}
            false
          else
            true
          end
        }
      end
      @links
    end

    def title
      @title ||= html.css('#events h1 a')[0].inner_text.strip
    end

    def description
      @description ||= html.css('#events h2')[0].inner_text.strip
    end
  end
end

