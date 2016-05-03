# encoding: utf-8
require_relative 'common'

def printUsage
    puts 
    puts "Touch each URL to get its download size and write it to disk."
    puts "Usage:  #{$0} roku_language.xml"
    exit
end

def printHeritage( item )
    str = ''

    item.ancestors.reverse.each do |parent|
        str += "#{parent['title']} -> " if parent['title']
    end

    if item['title']
      str += item['title']
    else  # this node doesn't have a title attribute so look for a child element
      str += item.css('title').text()
    end

    return str
end

class ThreadPool
  def initialize(size)
    @size = size
    @jobs = Queue.new
    @pool = Array.new(size) do
      Thread.new do
        catch(:exit) do
          loop do
            job, args = @jobs.pop
            job.call(*args)
          end
        end
      end
    end
  end

  def schedule(*args, &block)
    @jobs << [block, args]
  end

  def shutdown
    @size.times do
      schedule { throw :exit }
    end

    @pool.map(&:join)
  end
end

def do_roku_split( file )
    data = File.open(file).read
    xml = Nokogiri::XML(data) 
    filepath = File.dirname(file)
    filebase = File.basename(file,'.*')
    subdir = filepath + '/' + filebase

    pool = ThreadPool.new(20)
    print_mutex = Mutex.new


    # See if each item's id is found in its urls
    items = xml.css("item")


    count = 0
    items.each do |item|
        #title = item.css('title').text()

        ['content','thumbnail'].each do |tag|
          item.css(tag).each do |vid|
            url = vid['url']
            
            pool.schedule(item,vid['url']) do |item,url|
              filesize = get_file_download_size( url )
              print_mutex.synchronize do
                if filesize < 1000  # if the detected file size is customarily small then it's a bad link
                  puts "INVALID URL: #{filesize} bytes -- #{url} [#{printHeritage(item)}]"
                else
                  puts "VALID URL: #{filesize} bytes -- #{url} "#[#{printHeritage(item)}]"
                end
              end # synchronize
            end # schedule
          end # each vid
        end # each tag
    end # each item

    # now check all the category thumbnail images
    xml.css('category').each do |category|
      item = category
      url = category['img']
      #pool.schedule(category,category['img']) do |item, url|
        filesize = get_file_download_size( url )
        print_mutex.synchronize do
          if filesize < 1000  # if the detected file size is customarily small then it's a bad link
            puts "INVALID URL: #{filesize} bytes -- #{url} [#{printHeritage(item)}]"
          else
            puts "VALID URL: #{filesize} bytes -- #{url} "#[#{printHeritage(item)}]"
          end
        end # synchronize
      #end # schedule
    end # each category

    pool.shutdown
end


printUsage if ARGV.count != 1

do_roku_split ARGV[0]

