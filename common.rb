# encoding: utf-8
require_relative 'utils'
require 'nokogiri'
require 'fileutils'

$downloaded_thumbnail_count = 0
$missing_thumbnail_count = 0
$downloaded_subtitles_count = 0
$missing_subtitles_count = 0

def get_filename_from_url( url )
    return '' if url == nil or url == ''
    ri = url.rindex('/')
    return url if ri == nil
    return url[(ri+1)..-1]
end

###############################
#  Video methods
def video_already_downloaded?( url )
    return false if url == nil or url == ''
    # get download filename
    filename = get_filename_from_url( url )
    return FileTest.file?("#{DOWNLOADED_VIDEO_DIR}/#{filename}")
end

###############################
#  Thumbnail methods
def get_thumbnail_filename( url )
    return '' if url == nil or url == ''
    filename = get_filename_from_url( url )
    return "#{DOWNLOADED_THUMBNAIL_DIR}/#{filename}"
end

def thumbnail_already_downloaded?( url )
    return false if url == nil or url == ''
    return FileTest.file?(get_thumbnail_filename( url ))
end

def download_thumbnail( url )
    filename = get_thumbnail_filename( url )
    if filename == nil or filename == ''
        puts "ERROR: invalid filename!"
    end
    
    data = OpenURL( url, filename )
    if data != nil and data != '' and data.length > 0
        $downloaded_thumbnail_count += 1
    else
        $missing_thumbnail_count += 1
    end
end

###############################
#  Subtitle methods
def get_subtitles_filename( url )
    return '' if url == nil or url == ''
    filename = get_filename_from_url( url )
    return "#{DOWNLOADED_SUBTITLES_DIR}/#{filename}"
end

def subtitles_already_downloaded?( url )
    return false if url == nil or url == ''
    return FileTest.file?(get_subtitles_filename( url ))
end

def download_subtitles( url )
    filename = get_subtitles_filename( url )
    if filename == nil or filename == ''
        puts "ERROR: invalid filename!"
    end
    
    data = OpenURL( url, filename )
    if data != nil and data != '' and data.length > 0
        $downloaded_subtitles_count += 1
    else
        $missing_subtitles_count += 1
    end
end

def print_and_save_download_stats
    if $downloaded_thumbnail_count > 0
        puts "Downloaded #{$downloaded_thumbnail_count} missing thumbnails.  Recopy the thumbnail folder to the USB device."
    end
    if $downloaded_subtitles_count > 0
        puts "Downloaded #{$downloaded_subtitles_count} missing subtitles.  Recopy the subtitles folder to the USB device."
    end

    if $missing_thumbnail_count > 0
        puts "WARNING: #{$missing_thumbnail_count} thumbnails are still missing!"
    end
    if $missing_subtitles_count > 0
        puts "WARNING: #{$missing_subtitles_count} subtitles are still missing or non-existent!"
    end

    if $failed_URLs.count > 0
        puts "Failed URLs: #{$failed_URLs.count}. Refer to url_failures.txt for more information."

        failures = ""

        $failed_URLs.each do |url,count|
            failures += "#{url}\n"
        end
        WriteToFile("url_failures.txt",failures)
    end
end

