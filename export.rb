# encoding: utf-8
require_relative 'common'
require 'net/http'
require_relative 'languages'

ROKU_USB_VIDEO_PREFIX = "ext1:/LDS Media"
ROKU_USB_THUMBNAIL_PREFIX = "ext1:/LDS Media/thumbnails"
ROKU_USB_SUBTITLES_PREFIX = "ext1:/LDS Media/subtitles"
ROKU_XML_HOST  = "paulwhiting.github.io"
ROKU_XML_SUBDIR = "/GospelLibraryVideos/roku_channel"

def printUsage
    puts "Usage:  #{$0} video_directory"
    puts "video_directory - the location of your downloaded videos"
    exit
end

def download_latest_XML( language )
    puts "Checking for updated #{language} file..."
    download = false
    localfile = "medialibrary_#{language}.xml"
    mod_time_remote = nil
    mod_time_local = nil
    url = 'http://' + ROKU_XML_HOST + ROKU_XML_SUBDIR + "/#{localfile}"
    begin
        mod_time_local = File.mtime(localfile)
    rescue Errno::ENOENT
        puts "Local file missing."
        download = true
    end

    if mod_time_local
        begin
            puts "local file time: #{mod_time_local}"
            Net::HTTP.start(ROKU_XML_HOST) do |http|
                response = http.request_head(ROKU_XML_SUBDIR + "/#{localfile}")
                mod_date = response['Last-Modified'] # => Sat, 04 Jun 2011 08:51:44 GMT
                mod_time_remote = Time.parse(mod_date)
                puts "#{language} updated at:  #{mod_time_remote}"
                #puts "Size = #{response.header["Content-Length"].to_i}"
            end
            if mod_time_local == mod_time_remote
                puts "File is up to date"
            else
                download = true
            end
        rescue Exception => msg
            puts "Error downloading file metadata:  #{msg}"
        end
    end

    if download
        puts "Downloading #{url}"
        begin
            data = open(url,"rb").read
        rescue Exception => msg
            puts "Error downloading file:  #{msg}"
        end
          
        WriteToFile(localfile,data)
        File.utime( mod_time_remote, mod_time_remote, localfile )
    end
end

def do_roku_export( language )
    data = File.open("medialibrary_#{language}.xml").read
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

    # query again and see how many remain after we've removed non-downloaded URLs
    contents = xml.css("content")
    if contents.count == 0
      puts "No content found.  Skipping #{language}\n\n"
      return
    end

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

    # phase 3 - download category thumbnails, remove all empty categories, and update Video counts
    filename = "medialibrary_downloaded_#{language}.xml"
    puts "\nUpdating #{filename}\n\n"
    categories = xml.css("category")
    categories.each do |category|
        count =  category.css("item").count
        if count > 0
            category['subtitle'] = "Videos: #{count}"

            # Do thumbnail stuff
            url = category['img']
            if not thumbnail_already_downloaded?( url )
                puts "Downloading missing thumbnail: #{url}"
                download_thumbnail( url ) 
            end
            category['img'] = "#{ROKU_USB_THUMBNAIL_PREFIX}/#{File.basename(url)}"
        else
            category.remove
        end
    end

    # phase 4 - save file
    WriteToFile(filename,xml.to_s)

    print_and_save_download_stats
end


printUsage if ARGV.count != 1

# normalize input
directory = ARGV[0].chomp('/').chomp('\\')

DOWNLOADED_VIDEO_DIR = directory
DOWNLOADED_THUMBNAIL_DIR = "#{directory}/thumbnails"
DOWNLOADED_SUBTITLES_DIR = "#{directory}/subtitles"

if not Dir.exists? DOWNLOADED_VIDEO_DIR
  puts "Error:  Downloaded video directory '#{directory}' does not exist.  Aborting."
  exit
end

if not Dir.exists? DOWNLOADED_THUMBNAIL_DIR
  puts "Creating thumbnail directory '#{DOWNLOADED_THUMBNAIL_DIR}'"
  Dir.mkdir DOWNLOADED_THUMBNAIL_DIR
end

if not Dir.exists? DOWNLOADED_SUBTITLES_DIR
  puts "Creating thumbnail directory '#{DOWNLOADED_SUBTITLES_DIR}'"
  Dir.mkdir DOWNLOADED_SUBTITLES_DIR
end

# language list is pulled from languages.rb
LIBRARY_LANGUAGES.each do |threesome|
    filename, title, tag = threesome
    language = filename
    download_latest_XML( language )
    do_roku_export( language )
end

puts "Program finished!  Currently the Gospel Library Videos Roku channel only supports one downloaded language at a time.  Pick the language file you wish to use (i.e., medialibrary_downloaded_English.xml) and rename it to medialibrary_downloaded.xml and save it to the USB drive's root directory.  Don't forget to copy over your videos as well!" 

