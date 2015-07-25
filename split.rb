# encoding: utf-8
require_relative 'common'
require 'net/http'
require 'fileutils'     # for mkdir_p

ROKU_USB_VIDEO_PREFIX = "ext1:/LDS Media"
ROKU_USB_THUMBNAIL_PREFIX = "ext1:/LDS Media/thumbnails"
ROKU_USB_SUBTITLES_PREFIX = "ext1:/LDS Media/subtitles"
ROKU_XML_HOST  = "paulwhiting.github.io"
ROKU_XML_SUBDIR = "/GospelLibraryVideos/roku_channel"

def printUsage
    puts "Usage:  #{$0} roku_language.xml"
    exit
end

def do_roku_split( file )
    data = File.open(file).read
    xml = Nokogiri::XML(data) 
    filepath = File.dirname(file)
    filebase = File.basename(file,'.*')
    subdir = filepath + '/' + filebase

    FileUtils::mkdir_p subdir

    # phase 1 - remove all dead videos and update URL to Roku
    categories = xml.css("categories").children

    count = 0
    categories.each do |child|
        next if child.name != 'category'
        filename = child['title'].gsub(/[ \/]/,"_") + '.xml'

        if (child.children.length > 0 and child.children[0].name == 'rss')
          #puts "found rss element for #{child['title']}"
          content = ''
          wrapper = false
        else
          # If not rss then we need a wrapper
          content = '<categories>'
          wrapper = true
        end
          
        
        child.children.each do |item| content += item.to_s end
        content += '</categories>' if wrapper
        WriteToFile(subdir + '/' + filename,content)

        # now remove them
        child.children.each do |item| item.remove end

        child['url'] = 'http://' + ROKU_XML_HOST + ROKU_XML_SUBDIR + '/' + filebase + '/' + filename
    end

    # phase 4 - save file
    filename = filepath + '/' + filebase + '_root.xml'
    WriteToFile(filename,xml.to_s)
end


printUsage if ARGV.count != 1

do_roku_split ARGV[0]

