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

    old = xml_old.css("item")
    old_ids = Hash.new(0)
    old.each do |old_item|
      old_ids[old_item.at_css(:id).content] += 1
    end
      

    ##### phase 1 - Remove all items that are the same (by id).  For better or worse
    # this also avoids showing old videos that get moved/copied to a new location
    # in the hierarchy
    items = xml.css("item")

    print "Detecting #{items.count} items..."
    count = 0
    items.each do |item|
        count += 1
        PrettyPrint '.' if count % 100 == 0
        id = item.at_css(:id).content
        if old_ids[id] > 0
          #puts "Duplicate!"
          item.remove
        else
          #puts "Unique!"
        end
    end

    items = xml.css("item")
    puts "found #{items.count} new items."

    # phase 2 - remove all empty categories and update Video counts
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

    # phase 3 - save file
    WriteToFile(filename,xml.to_s)

    print_and_save_download_stats
end


printUsage if ARGV.count != 2
XML_NEW = ARGV[0]
XML_OLD = ARGV[1]

do_roku_diff

