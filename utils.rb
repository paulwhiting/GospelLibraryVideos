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

def OpenURL(url,filename,bRetry=true)
    PrettyPrint "."
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
                if m != nil and m.captures.length == 2
                    #puts "HERE WE ARE!"
                    # m0 is full match, 1 first group 2 2nd
                    if m[2].start_with?( 'http:' ) and bRetry
                        newurl = m[2].gsub('http:','https:')
                        # retry with https
                        return OpenURL(newurl,filename,false)
                    end
                end
            end

            if e.to_s.include?("Timeout::Error")
              PrettyPrintNewline "Exception with downloading #{url} -- #{e.to_s} -- Retrying."
              return OpenURL(url,filename,true)
            elsif e.to_s.include?("400 Bad Request")
              PrettyPrintNewline "Exception with downloading #{url} -- #{e.to_s} -- Retrying."
              return OpenURL(url,filename,true)
            else
              PrettyPrintNewline "Exception with downloading #{url} -- #{e.to_s}"
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

