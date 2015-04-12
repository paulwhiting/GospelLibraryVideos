# encoding: utf-8
require_relative 'common'

ROKU_USB_VIDEO_PREFIX = "ext1:/LDS Media"
ROKU_USB_THUMBNAIL_PREFIX = "ext1:/LDS Media/thumbnails"
ROKU_USB_SUBTITLES_PREFIX = "ext1:/LDS Media/subtitles"

def printUsage
    puts "Usage:  diff.rb new.xml old.xml"
    exit
end

def do_roku_diff
    data = File.open(XML_NEW).read
    xml = Nokogiri::XML(data) 

    data = File.open(XML_OLD).read
    xml_old = Nokogiri::XML(data) 

    old = xml_old.css("content")
    old_urls = Hash.new(0)
    old.each do |old_content|
      old_urls[old_content['url']] += 1
    end
      

    # phase 1 - remove all video content that is the same
    contents = xml.css("content")

    print "Detecting #{contents.count} video links..."
    count = 0
    contents.each do |content|
        count += 1
        PrettyPrint '.' if count % 100 == 0
        url = content['url']
        if old_urls[url] > 0
          #puts "Duplicate!"
          content.remove
        else
          #puts "Unique!"
        end
    end

    contents = xml.css("content")
    puts "found #{contents.count}."

    # phase 2 - remove all empty items
    puts "Removing empty items"
    items = xml.css("item")
    items.each do |item|
        if item.css("content").count > 0
        else
            item.remove
        end
    end


    # phase 3 - remove all empty categories and update Video counts
    filename = "medialibrary_diff.xml"
    puts "\n\nUpdating #{filename}"
    categories = xml.css("category")
    categories.each do |category|
        count =  category.css("item").count
        if count > 0
            category['subtitle'] = "Videos: #{count}"
        else
            category.remove
        end
    end

    # phase 4 - save file
    WriteToFile(filename,xml.to_s)

    print_and_save_download_stats
end


printUsage if ARGV.count != 2
XML_NEW = ARGV[0]
XML_OLD = ARGV[1]

do_roku_diff

