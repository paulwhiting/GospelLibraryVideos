# encoding: utf-8
require_relative 'common'

ROKU_USB_VIDEO_PREFIX = "ext1:/LDS Media"
ROKU_USB_THUMBNAIL_PREFIX = "ext1:/LDS Media/thumbnails"
ROKU_USB_SUBTITLES_PREFIX = "ext1:/LDS Media/subtitles"

def printUsage
    puts "Please specify your LDS Media video directory"
    exit
end

def do_roku_export
    data = File.open("medialibrary.xml").read
    xml = Nokogiri::XML(data) 

    FileUtils::mkdir_p DOWNLOADED_SUBTITLES_DIR

    # phase 1 - remove all dead videos and update URL to Roku
    contents = xml.css("content")

    print "Detecting #{contents.count} video links..."
    count = 0
    contents.each do |content|
        count += 1
        PrettyPrint '.' if count % 100 == 0
        url = content['url']
        if video_already_downloaded?( url )
            content['url'] = "#{ROKU_USB_VIDEO_PREFIX}/#{File.basename(url)}"
        else
            # missing, so delete it
            content.remove
        end
    end

    contents = xml.css("content")
    puts "found #{contents.count}."

    # phase 2 - remove all empty items and update subtitles and thumbnails
    puts "Removing empty items and downloading subtitles and thumbnails..."
    items = xml.css("item")
    items.each do |item|
        if item.css("content").count > 0
            # Do thumbnail stuff
            thumb = item.at_css('thumbnail')
            url = thumb['url']
            if not thumbnail_already_downloaded?( url )
                puts "Downloading missing thumbnail: #{url}"
                download_thumbnail( url ) 
            end
            thumb['url'] = "#{ROKU_USB_THUMBNAIL_PREFIX}/#{File.basename(url)}"

            # now do subtitle stuff
            cc = item.at_css('subtitles')
            if cc != nil
                url = cc['url']
                if not subtitles_already_downloaded?( url )
                    puts "Downloading missing subtitles: #{url}"
                    download_subtitles( url ) 
                end
                cc['url'] = "#{ROKU_USB_SUBTITLES_PREFIX}/#{File.basename(url)}"
            end
        else
            item.remove
        end
    end

    items = xml.css("item")
    #puts "#{items.count} items remaining."

    # phase 3 - remove all empty categories and update Video counts
    filename = "medialibrary_downloaded.xml"
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


printUsage if ARGV.count != 1
DOWNLOADED_VIDEO_DIR = ARGV[0]
DOWNLOADED_THUMBNAIL_DIR = "#{ARGV[0]}/thumbnails"
DOWNLOADED_SUBTITLES_DIR = "#{ARGV[0]}/subtitles"

do_roku_export

