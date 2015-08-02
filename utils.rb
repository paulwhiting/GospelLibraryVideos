# encoding: utf-8
require 'open-uri'

# for https stuff
require 'net/https'
require 'openssl'

$failed_URLs = Hash.new(0)
$blacklisted_URLs = Hash.new(0)
$cached_file_sizes = Hash.new(0)
$detected_file_sizes = Hash.new(0)

def PrettyPrint( str )
    print str
end

def PrettyPrintNewline( str )
    puts ''
    print str
end

def WriteToFile(filename,data)
    file = File.new(filename,"wb")
    file.write(data)
    file.close
end

def OpenURL(url,filename,retrycount=3)
    PrettyPrint '.'
    data = nil

    if $failed_URLs[url] != 0
        # skip previous bad urls
        return nil
    end

    if $blacklisted_URLs[url] != 0
        # skip previous bad urls
        return nil
    end

    if not File.exists?(filename)
        #puts "Downloading #{filename} from #{url}"
        begin
            #data = open(url,"rb").read
            data = open(url,"rb", ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE).read
            WriteToFile(filename,data)
        rescue => e
            # Silently fix redirection issues
            e.to_s.match(/redirection forbidden: (\S+) -> (\S+)/) do |m|
                #puts "REDIRECTION DETECTED!"
                if m != nil and m.captures.length == 2
                    ## m0 is full match, 1 first group 2 2nd
                    if retrycount > 0
                        newurl = m[2]
                        return OpenURL(newurl,filename,retrycount-1)
                    end
                end
            end

            if retrycount > 0 
              PrettyPrintNewline "EXCEPTION with downloading #{url} -- #{e.to_s} -- Retrying (#{retrycount})"
              return OpenURL(url,filename,retrycount-1)
            else
              PrettyPrintNewline "ERROR with downloading #{url} -- #{e.to_s} -- SKIPPING"
              $failed_URLs[url] += 1
            end
        end
    else
        #puts "Reading #{filename}..."
        data = File.read(filename)
    end
    return data
end

def load_blacklisted_urls
    data = File.read("url_blacklist.txt")
    data.each_line do |line|
        $blacklisted_URLs[line.chomp] = 1
    end
end

def load_cached_file_sizes
    data = File.read("url_cached_file_sizes.txt")
    data.each_line do |line|
        size, url = line.split(' ')
        $cached_file_sizes[url] = size
    end

    puts "Loaded #{$cached_file_sizes.count} file sizes from the cache file."
end

def get_filename_from_url( url )
    return '' if url == nil or url == ''
    index = url.rindex('/')
    if index == nil
        return url
    end
    return url[(index+1)..-1]
end

def load_cached_subtitles
    $cached_subtitles = {}
    if not File.exist?("allcaptionfiles.txt")
        puts "url_subtitles.txt not found. No cached subtitles loaded."
    else
        data = File.read("allcaptionfiles.txt")
        data.each_line do |url|
            filename = get_filename_from_url(url).chomp.chomp('.xml')
            $cached_subtitles[filename] = url.chomp
        end
    end

    puts "Loaded #{$cached_subtitles.count} subtitles from the cache file."
end

