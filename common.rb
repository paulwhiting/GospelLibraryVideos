# encoding: utf-8
require_relative 'utils'
require 'nokogiri'
require 'fileutils'

$downloaded_thumbnail_count = 0
$missing_thumbnail_count = 0
$downloaded_subtitles_count = 0
$missing_subtitles_count = 0
$file_download_sizes = Hash.new(0)

def get_filename_from_url( url )
    return '' if url == nil or url == ''
    ri = url.rindex('/')
    return url if ri == nil
    return url[(ri+1)..-1]
end

class URLSizes
  @@sizes = {}
  @@mutex = Mutex.new

  ERR_NOT_SUCCESS = -1
  ERR_INVALID_URI = -2
  ERR_TOO_MANY_RETRIES = -3
  ERR_CONN_REFUSED = -4
  ERR_END_OF_FUNC = -5
  
  private_class_method
  def self.fetch_size( url, tries = 3 )
    #puts "Attempting #{url}"
    begin
      uri = URI(url)
      Net::HTTP.start(uri.host,uri.port,use_ssl: uri.scheme == 'https' ) do |http|
        response = http.request_head(uri.path)
        case response
        when Net::HTTPRedirection then
          return ERR_TOO_MANY_RETRIES if tries == 0  # redirected too many times
          return self.fetch_size( response['location'], tries - 1 )
        when Net::HTTPSuccess then
          size = response.header["Content-Length"].to_i
          #PrettyPrintNewline "Detected Size = #{size}"
          return size
        else
          return ERR_NOT_SUCCESS
        end
      end # HTTP.start
    rescue Errno::ECONNREFUSED
      return ERR_CONN_REFUSED
    rescue URI::InvalidURIError
      return ERR_INVALID_URI
    rescue Timeout::Error
      return ERR_TOO_MANY_RETRIES if tries == 0  # tried too many times
      return self.fetch_size( url, tries-1 ) if tries > 0
    end

    return ERR_END_OF_FUNC
  end

  # memoize!
  def self.get_size( url )
    return @@sizes[url] if @@sizes[url]
    size = self.fetch_size( url )
    @@mutex.synchronize do
      @@sizes[url] = size
    end
  end

end

def get_file_download_size( url )
  return URLSizes.get_size(url)
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

