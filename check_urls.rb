# encoding: utf-8
require_relative 'common'

def printUsage
    puts 
    puts "See if each video's ID is found it its URLs"
    puts "Usage:  #{$0} roku_language.xml"
    exit
end

def do_roku_split( file )
    data = File.open(file).read
    xml = Nokogiri::XML(data) 
    filepath = File.dirname(file)
    filebase = File.basename(file,'.*')
    subdir = filepath + '/' + filebase


    # See if each item's id is found in its urls
    items = xml.css("item")

    count = 0
    items.each do |item|
        title = item.css('title').text()
        id = item.css('id').text().downcase

        ['-eng','-spa','-por'].each do |ending|
          id = id.chomp(ending) if id.end_with?(ending)
        end
        #puts title

        item.css("content").each do |vid|
          url = vid['url'].downcase
          if not url.include?( id )
            puts "#{id} is not in #{url}"
          end
        end
    end
end


printUsage if ARGV.count != 1

do_roku_split ARGV[0]

