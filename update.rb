# encoding: utf-8
require_relative 'common'
require 'zlib'          # for Zlib
require 'fileutils'     # for mkdir_p
require 'json'          # for JSON
require 'htmlentities'  # for HtmlEntities
require 'time'          # for Time

OUTPUT_DIR_PREFIX = "medialibrary_output/"
CONTENT_DIR_PREFIX = "medialibrary_output/content/"
HOSTING_URL  = "http://paulwhiting.github.io/GospelLibraryVideos"

require 'sqlite3'
# the subdirectory we want to store our content in
COVER_ART_URL = "http://broadcast3.lds.org/crowdsource/Mobile/GospelStudy/production/v1"
COVERS_SHOW_EMPTY = true
IGNORE_OBSOLETE = true

$book_cache = {}

def UpdateBookEntryDatabase(db,catalog_id,book_id,xml)
    db.execute( "INSERT or replace INTO books ( catalog_id, book_id, content ) VALUES ( ?, ?, ? )", [catalog_id, book_id, xml])
end

def TreeifyBookEntries(entries,param_id)
    results = {}
    entries.each do |id,entry|
        next if entry.parent_id != param_id
        results[id] = entry
        results[id].children = TreeifyBookEntries(entries,id)
    end
    return results
end

class Video_GospelLibrary
    attr_accessor :url
    attr_accessor :title
    attr_accessor :size
    attr_accessor :duration

	def initialize( params )
        title = params[:parent_title]

        if params[:title]
            title = params[:title]
            # clean up the title name
            #title.gsub!(/[“”",.)]*$/,'')
            #title.gsub!(/^[“”",.)]*/,'')
            #title = title.chomp('.').chomp(',')
        end

        @url = params[:url]
        @title = HTMLEntities.new.encode(title)
        @size = params[:size]
        @duration = params[:duration]
    end
end


def getVideos(url,filename)
    zbook = OpenURL(url,filename)
    filename_sql = filename + '.sql'

    return {} if zbook == nil

    sql = Zlib::Inflate.inflate(zbook)
    WriteToFile(filename_sql,sql)

    entries = {}
    dbname = filename_sql
    db = SQLite3::Database.new( dbname )
    count = 0
    totalsize = 0
    videos = {}
    results = db.execute( "select id,parent_id,title,subtitle,short_title,content from node" )
    results.each do |row|
        next if not row
        params = {  id: row[0],
                    parent_id: row[1],
                    title: row[2],
                    subtitle: row[3],
                    short_title: row[4],
                    content: row[5] }

        entry = BookEntry.new(params)

        #puts "Processing :: #{params[:id]} - #{params[:parent_id]} - #{params[:title]}"

        if params[:content]
            xml = Nokogiri::HTML(params[:content])
            #v = xml.css("div[class=video]")
            v = xml.css("video")
            v.each {|item|
                video_title = nil
                begin
                    #this line works for come follow me
                    video_title = item.parent.parent['title']
                rescue
                    puts "exception getting parent title!"
                end
                if video_title == nil
                    #puts "title missing!" #  setting to default..."
                    #video_title = params[:title] 
                end
                src = item.children.css("source[data-container=mp4]")
                bytes = 0
                url = ''
                duration = 0
                src.each {|s|
                    if s['data-sizeinbytes'].to_i < bytes or bytes == 0
                        bytes = s['data-sizeinbytes'].to_i
                        url = s['src']
                        duration = s['data-durationms'].to_i / 1000
                    end
                }

                #puts "#{video_title} - #{bytes}"

                count += 1
                totalsize += bytes
                v = Video_GospelLibrary.new(url: url, parent_title: params[:title], title: video_title, size: bytes, duration: duration)
                videos[url] = v

                entry.add_video(v)
            }
        end

        entries[params[:id]] = entry
    end

    return entries
end


class CatalogEntry
    attr_accessor :catalog_id
    attr_accessor :id
    attr_accessor :name
    attr_accessor :cover_art

    attr_accessor :url
    attr_accessor :filename

    attr_accessor :children
    attr_accessor :books
    attr_accessor :video_count

    def initialize( catalog_id, id, name, cover_art )
        @catalog_id = catalog_id
        @id = id
        @name = name
        @cover_art = cover_art
        if @cover_art == nil
            @cover_art = ''
        else
            @cover_art = @cover_art.gsub(/{\d*}/,'@2x')
        end
        
        @video_count = 0
        @url = ""
        @filename = ""
        @books = {}
        @children = {}
    end

    def setURLInfo(url,filename)
        @url = url
        @filename = CONTENT_DIR_PREFIX + "catentry_#{@catalog_id}_#{filename}"
    end

    def setChildren(children)
        @children = children
    end

    def getBookEntries
        #if @url != "" and @id == 23637 #... for quick testing hungarian
        #if @url != "" and @id == 24825 #... for quick testing english
        if @url != ""
            if $book_cache[@url]
                puts "Cached URL is #{@url}"
                @books = $book_cache[@url]
            else
                puts "New URL is #{@url}"
                entries = getVideos(@url,@filename)
                # result is an array of miscellaneous BookEntries
                # Convert to an array of ordered tree BookEntries
                @books = TreeifyBookEntries(entries,0)
                $book_cache[@url] = @books
            end
        end

        if @children
            @children.each do |id,item|
                item.getBookEntries
            end
        end
    end

    def calculateVideoCount
        @video_count = 0
        @children.each do |id,item|   #item is CatalogEntry
            @video_count += item.calculateVideoCount
        end
        @books.each do |id,item|   #item is BookEntry
            @video_count += item.calculateVideoCount
        end
        return @video_count
    end

    def printEntries(indent)
        puts "    "*indent + @name + "(#{url})"
        if @children
            @children.each do |id,item|
                item.printEntries(indent+1)
            end
        end
    end

    def updateDatabaseXML( db )
        return if @video_count == 0    # don't do anything if no vids

        @children.each do |id,item|    #item is CatalogEntry
            item.updateDatabaseXML( db )
        end
        
        if @books.count > 0
            str = "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<categories>"
            @books.each do |id,item|   #item is BookEntry
                str += item.to_xml
            end
            str += "</categories>"
            puts "updating db for #{@catalog_id}, #{@id}"
            #puts str
            UpdateBookEntryDatabase(db,@catalog_id,@id,str)
        end
    end

    def to_xml
        return "" if @video_count == 0
        cover_art = getClosestCoverArt
        str = "<category title='#{HTMLEntities.new.encode(@name)}' subtitle='Videos: #{@video_count}' url='#{@url != '' ? "#{HOSTING_URL}/langs/#{@catalog_id}/books/#{@id}.xml" : ''}'"
        str +=  " img='#{COVER_ART_URL}/#{cover_art}'" if cover_art != ''
        #str += " showAsList='1'"
        str += ">"

        @children.each do |id,child|
            str += child.to_xml
        end

        return str + "</category>"
    end

    def getClosestCoverArt
        return @cover_art if @cover_art != '' and (COVERS_SHOW_EMPTY or @video_count > 0)

        @children.each do |id,item|    #item is CatalogEntry
            cover = item.getClosestCoverArt
            return cover if cover != '' and (COVERS_SHOW_EMPTY or item.video_count > 0)
        end

        return ''
    end
end

class Language
    attr_accessor :name
    attr_accessor :id
    attr_accessor :catalog
    attr_accessor :video_count

    LANGUAGE_URL  = "http://tech.lds.org/glweb?action=languages.query&format=xml"
    LANGUAGE_FILE = CONTENT_DIR_PREFIX + "languages.xml"
    #PLATFORM_ID = 1  # iphone
    PLATFORM_ID = 17  # android

    def self.getList
        data = OpenURL(LANGUAGE_URL, LANGUAGE_FILE)
        xml = Nokogiri::XML(data) 

        elements = xml.css("language")

        languages = {}
        elements.each {|item|
            id = item['ID'].to_i
            name = item.children.css("eng_name").text
            #puts "#{id} - #{name}"
            languages[id] = Language.new(id,name)
        }

        return languages
    end

    def initialize( id, name )
        @id = id
        @name = name
        @video_count = 0
    end

    def parseEntryJson(elements)
        return {} if elements.count == 0
        results = {}
        elements.each do |id,data|
            #parse folders
            if id == 'folders'
                #puts "folders!"
                data.each do |folderdata|
                    if folderdata['obsolete'] != nil and folderdata['obsolete'] != ""
                        next if IGNORE_OBSOLETE
                    end
                    #next if folderdata['obsolete'] != nil
                    name = HTMLEntities.new.decode(folderdata['name'])
                    id = folderdata['id']
                    cover_art = folderdata['cover_art']
                    subresults = parseEntryJson(folderdata)
                    results[id] = CatalogEntry.new(@id,id,name,cover_art) #@id is catalog id, id is entry id
                    results[id].setChildren(subresults)
                end
            end
            if id == 'books'
                #puts "    books!"
                data.each do |bookdata|
                    if bookdata['obsolete'] != nil and bookdata['obsolete'] != ""
                        next if IGNORE_OBSOLETE
                    end
                    name = HTMLEntities.new.decode(bookdata['name'])
                    id = bookdata['id']
                    url = bookdata['url']
                    file = bookdata['file']
                    cover_art = bookdata['cover_art']
                    subresults = parseEntryJson(bookdata)
                    results[id] = CatalogEntry.new(@id,id,name,cover_art) #@id is catalog id, id is entry id
                    results[id].setURLInfo(url,file)
                    results[id].setChildren(subresults)
                end
            end
        end
        return results
    end

    def getCatalogEntries
        catalog_url = "http://tech.lds.org/glweb?action=catalog.query&languageid=#{@id}&platformid=#{PLATFORM_ID}&format=json"
        catalog_file = CONTENT_DIR_PREFIX + "catalog_#{@id}.json"
        data = OpenURL(catalog_url, catalog_file)
        if data == nil or data == ""
            puts "URL data nil!"
            return {}
        end
        elements = JSON.parse(data)

        results = parseEntryJson(elements['catalog'])
        @catalog = results
        return @catalog
    end

    def getBookEntries
        @catalog.each do |id,item|
            item.getBookEntries
        end
    end

    def calculateVideoCount
        @video_count = 0
        @catalog.each do |id,item|   #item is CatalogEntry
            @video_count += item.calculateVideoCount
        end
    end


    def updateDatabaseXML( db )
        puts "Updating Language #{@id}"
        if @video_count == 0
            puts "No videos!  Skipping #{@name} language :("
            return
        end
        str = "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
        <categories>"
        @catalog.each do |id,item|
            puts "Processing #{id}..."
            item.updateDatabaseXML(db)
            str += item.to_xml
        end 
        str += "</categories>"
        #puts str
        db.execute( "INSERT or replace INTO catalogs ( id, content ) VALUES ( ?, ? )", [@id, str])
    end

    def to_titlepage_xml
        return "" if @video_count == 0
        cover = getClosestCoverArt
        cover = " img='#{COVER_ART_URL}/#{cover}'" if cover != ''
        
        return "<category title='#{HTMLEntities.new.encode(@name)}' url='#{HOSTING_URL}/langs/#{@id}.xml' subtitle='Videos: #{@video_count}'#{cover}/>"
    end

    def getClosestCoverArt
        @catalog.each do |id,item|  #item is CatalogEntry
            cover = item.getClosestCoverArt
            return cover if cover != '' and (COVERS_SHOW_EMPTY or item.video_count > 0)
        end

        return ''
    end

    def printCatalog
        puts @name
        @catalog.each do |id,item|
            item.printEntries(1)
        end
    end
end

class BookEntry
    attr_accessor :id
    attr_accessor :parent_id
    #attr_accessor :name
    attr_accessor :videos
    attr_accessor :children
    attr_accessor :video_count

	def initialize( params )
        @id = params[:id]
        @parent_id = params[:parent_id]
		@title = params[:title]
		@subtitle = params[:subtitle]
		@short_title = params[:short_title]
        @videos = {}
        @children = []
	end

    def add_video( video )
        #puts "video.url #{video.url} is added!"
        if @videos[video.url] != nil
            #puts "Duplicate video found!"
        else
            @videos[video.url] = video
        end
    end

    def calculateVideoCount
        @video_count = 0
        @children.each do |id,item|  # item is BookEntry
            @video_count += item.calculateVideoCount
        end
        @video_count += @videos.count

        #puts "#{@video_count} videos!"
        return @video_count
    end

    def to_xml
        return "" if @video_count == 0
        str = "<category title='#{HTMLEntities.new.encode(@title)}' subtitle='Videos: #{@video_count}'>"  # showAsList='1'>"
        @children.each do |id,item|
            str += item.to_xml
        end
        if @videos.count > 0
            str += "<rss> <channel> <title>SomeTitleHere</title> <description>SomeDescriptionHere</description>"
            @videos.each do |id,video|
                str += "<item>
                    <title>#{video.title}</title>
                    <description>Description: #{video.title}</description>
                    <content url='#{video.url}'/>
                    <duration>#{video.duration}</duration>
                    </item>"
            end
            str += " </channel> </rss>"
        end
        return str + "</category>"
    end
end


def DoUpdateXML( dbname, requested_id )
    langs = Language.getList
    puts "Requested ID = #{requested_id}"

    db = SQLite3::Database.new( dbname )
    #db.execute("drop table if exists catalogs")
    #db.execute("drop table if exists books")
    db.execute("create table if not exists catalogs(id INTEGER PRIMARY KEY, content);")
    db.execute("create table if not exists books(catalog_id INTEGER, book_id INTEGER, content, PRIMARY KEY (catalog_id,book_id));")


    langstr = "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
    <categories>"

    #  Output lovely XML for the catalog
    langs.each do |id,language|
        next if requested_id != 0 and requested_id != id
        puts "Processing language id #{id}..."
        catalog = language.getCatalogEntries
        language.getBookEntries
        language.calculateVideoCount

        language.updateDatabaseXML(db)
        langstr += language.to_titlepage_xml
    end
    langstr += "</categories>"

    db.execute( "INSERT or replace INTO catalogs ( id, content ) VALUES ( ?, ? )", [0, langstr])

    db.close

    puts "Unique URLs: #{$book_cache.count}"
    puts "Failed URLs: #{$failed_URLs.count}"

    failures = ""

    $failed_URLs.each do |url,count|
        failures += "#{count}  -  #{url}\n"
    end

    WriteToFile(OUTPUT_DIR_PREFIX + "url_failures.txt",failures)
end


def DoExport(dbname, dirname)

    Dir.mkdir dirname if not Dir.exists?(dirname)

    db = SQLite3::Database.new( dbname )
    stm = db.prepare "SELECT * from catalogs;"
    rows = stm.execute

    rows.each do |row|
        id = row[0]
        xml = row[1].gsub(/http:\/\/192.168.0.19:3000\/langs\/(\d*?)\.xml/,'pkg:/xml/lang_\1.xml')
        xml = xml.gsub(/http:\/\/192.168.0.19:3000\/langs\/(\d*)\/books\/(\d*).xml/,'pkg:/xml/lang_\1_book_\2.xml')
        f = File.open("#{dirname}/lang_#{id}.xml","wb")
        f.write xml
        f.close
    end

    stm.close

    stm = db.prepare "SELECT * from books;"
    rows = stm.execute

    rows.each do |row|
        lang_id = row[0]
        book_id = row[1]
        xml = row[2]
        f = File.open("#{dirname}/lang_#{lang_id}_book_#{book_id}.xml","wb")
        f.write xml
        f.close
    end

    stm.close
    db.close
end

#############################################
#############################################

#  Where the Media Library / Glancy parser code begins

ROKU_USB_VIDEO_PREFIX = "ext1:/LDS Media"
ROKU_USB_THUMBNAIL_PREFIX = "ext1:/LDS Media/thumbnails"
ROKU_USB_SUBTITLES_PREFIX = "ext1:/LDS Media/subtitles"

$unique_videos = {}

def get_filename_from_url( url )
    return '' if url == nil or url == ''
    return url[(url.rindex('/')+1)..-1]
end

def durationStrToInt( duration )
    t1 = Time.parse( "2015-01-01 00:00:00" )

    count = duration.count ':'
    if count == 0 # only seconds? (right format)
        return duration.to_i
    elsif count == 1 # mins and seconds
        t2 = Time.parse( "2015-01-01 00:#{duration}" )
    elsif count == 2 # hours mins and seconds
        t2 = Time.parse( "2015-01-01 #{duration}" )
    else
        t2 = t1
    end

    return (t2 - t1).to_i
end
    
class VideoStream
    attr_accessor :url
    attr_accessor :quality
    attr_accessor :size

	def initialize( params )
        @url = params[:url]
        @quality = params[:quality].to_i
        @size = params[:size].to_i
        @size = 0 if @size == nil
    end

    def to_xml
        "<content url='#{@url}' height='#{@quality}'/>"
    end
end

def FixURL( params )
    if params[:title] == "Step Two: Hope" and params[:quality].to_i == 1080 and params[:url] == "http://media2.ldscdn.org/assets/welfare/lds-addiction-recovery-program-twelve-step-video-series/2012-12-001-step-one-honesty-1080p-eng.mp4"
        PrettyPrintNewline "Fixing Addiction Step Two URL..."
        return "http://media2.ldscdn.org/assets/welfare/lds-addiction-recovery-program-twelve-step-video-series/2012-12-002-step-two-hope-1080p-eng.mp4"
    elsif params[:url] == "/pages/mormon-messages/images/voice-of-the-spirit-mormon-message-138x81.jpg"
        PrettyPrintNewline "Fixing Voice of the Spirit URL..."
        return "http://media.ldscdn.org/images/videos/mormon-channel/mormon-messages-2010/2010-08-16-voice-of-the-spirit-192x108-thumb.jpg"
    elsif params[:url].start_with?("https:")
        return params[:url].gsub("https:","http:")
    end
    return params[:url]
end

def FixQuality( title, quality )
    case quality
    when "1080p", "720p", "360p", "480p"
        # this is the default good case
        return quality
    when "1080", "1080P", "Large", "Large video"
        PrettyPrintNewline "Fixing quality '#{quality}' to 1080p for #{title}"
        return "1080p"
    when "720", "720P", "Medium", "Medium video"
        PrettyPrintNewline "Fixing quality '#{quality}' to 720p for #{title}"
        return "720p"
    when "360P", "Small", "Small video"
        PrettyPrintNewline "Fixing quality '#{quality}' to 360p for #{title}"
        return "360p"
    else
        PrettyPrintNewline "Fixing unknown quality '#{quality}' to 360p for #{title}"
        return "360p"
    end
end

def NormalizeParams( params )
    params[:title] = HTMLEntities.new.encode(params[:title]) if params[:title] != nil
    params[:duration] = durationStrToInt(params[:duration]) if params[:duration] != nil
    params[:summary] = HTMLEntities.new.encode(params[:summary]) if params[:summary] != nil
    params[:desc] = HTMLEntities.new.encode(params[:desc]) if params[:desc] != nil
    params[:quality] = FixQuality( params[:title], params[:quality] ) if params[:quality] != nil
    params[:url] = FixURL( title: params[:title], url: params[:url], quality: params[:quality] ) if params[:url] != nil
    return params
end

class Video
    attr_accessor :id
    attr_accessor :title
    attr_accessor :description
    attr_accessor :summary
    attr_accessor :duration
    attr_accessor :thumbnail
    attr_accessor :closedcaptions
    attr_accessor :streams
    attr_accessor :smallest_size
    attr_accessor :largest_size

	def initialize( params )
        params = NormalizeParams(params)
        @id = params[:id]
        @title = params[:title]
        @duration = params[:duration]
        @description = params[:desc]
        @summary = params[:summary]
        @thumbnail = params[:thumb]
        @closedcaptions = params[:cc]
        @closedcaptions = '' if @closedcaptions == nil
        @streams = []
        @smallest_size = 0
        @largest_size = 0
    end

    # expected url and quality
    def add( params )
        params[:title] = @title #we need the title to fix other params
        params = NormalizeParams(params)
        stream = VideoStream.new(params)
        if @smallest_size == 0 or stream.size < @smallest_size
            @smallest_size = stream.size
        end
        if stream.size > @largest_size
            @largest_size = stream.size
        end
        @streams << stream
    end

    def update_subtitles( cc )
        @closedcaptions = cc
    end

    def to_xml
        xml = "<item>
        <id>#{@id}</id>
        <title>#{@title}</title>
        <description>#{@summary}</description>
        <duration>#{@duration}</duration>
        <thumbnail url='#{@thumbnail}'/>\n"
        xml += "<subtitles url='#{@closedcaptions}'/>\n" if @closedcaptions != ''
        @streams.each do |stream|
            xml += stream.to_xml
        end
        xml += "</item>\n"

        return xml
    end

    def get_glancy_stream( quality )
        return "" if smallest_size == 0
        found_quality = 0
        found_stream = nil
        smallest_stream = nil
        @streams.each do |stream|
            # find the smallest video equal to or less than the quality
            if stream.quality > found_quality and stream.quality <= quality
                found_quality = stream.quality
                found_stream = stream
            end
            # as a backup grab the lowest quality video (which will be of higher quality than what they requested)
            if @smallest_size == stream.size
                smallest_stream = stream
            end
        end

        found_stream = smallest_stream if found_stream == nil
        return found_stream
    end

    def to_glancy_videoref( quality )
        return "" if @smallest_size == 0
        stream = get_glancy_stream( quality )
        if stream != nil
            found_url = stream.url
            # make sure if we have a duplicate video it has the right name
            if $glancy_videos[found_url] != nil
                v2 = $glancy_videos[found_url][0].title
                if v2 != @title
                    puts "WARNING:  URL title mismatch:  #{v2}  !=  #{@title}"
                end
            end
            $glancy_videos[found_url] = [self,stream]
            return "<videoref ref=\"#{found_url}\"/>" 
        end
        return ""
    end

    def self.to_glancy_video( video, stream )
        return "" if video.smallest_size == 0
        if stream != nil
            return "<video id=\"#{stream.url}\" name=\"#{video.title}\" thumbnail=\"#{video.thumbnail}\" url=\"#{stream.url}\"/>"
        end
        return ""
    end
end



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


class MediaLibraryEntry
    attr_accessor :name
    attr_accessor :id
    attr_accessor :entries
    attr_accessor :video_count
    attr_accessor :smallest_size
    attr_accessor :largest_size

    # Media gallery stuff
    MEDIA_LIBRARY_URL  = "https://www.lds.org/media-library/video/categories"

    def initialize( params )
        @title = params[:title]
        @url = params[:url]
        @img = params[:img]
        @img = "" if @img == nil
        @img.gsub!("https","http")
        @video_count = 0
        @entries = []
        @videos = []
        @smallest_size = 0
        @largest_size = 0
    end

    def self.getList  # returns MediaLibraryEntry
        return MediaLibraryEntry.new(title: "Media Library", url: MEDIA_LIBRARY_URL)
    end

    def parseURL
        filename = CONTENT_DIR_PREFIX + @url.gsub(/[:\/?&=]/,'_')
        data = OpenURL(@url, filename)
        html = Nokogiri::HTML(data) 

        # The good stuff is stored in <div id="primary">
        categories = html.css("div#primary ul[class='video-stacks'] li")

        categories.each {|item|
            name = item.children.css("h3").text.strip
            url = item.children.css("h3 a")[0]['href'].strip
            img = item.children.css("a img")[0]['src'].strip
            mle = MediaLibraryEntry.new(title: name,url: url, img: img)
            mle.parseURL if url
            @smallest_size += mle.smallest_size
            @largest_size += mle.largest_size
            @video_count += mle.video_count
            @entries << mle
        }
        #puts "Counted #{@entries.count} category items!"


        # find the one that has the video data... that's the one we want
        scripts = html.css("script")
        scripts.each {|item|
            next if not item.text.start_with? "video_data="
            start = 11
            last = item.text.rindex('}')
            text = item.text.slice(11..last)
            elements = JSON.parse(text)
            vids = parseEntryJson(elements)
            @video_count += vids.count
            @smallest_size += vids.map(&:smallest_size).inject(0, :+)
            @largest_size += vids.map(&:largest_size).inject(0, :+)
            @videos += vids
        }

        #puts "Counted #{@videos.count} items!"

        nexturl = html.css("a[class='next']")
        if nexturl != nil and nexturl[0] != nil
            #puts "next url is #{nexturl[0]['href']}"
            @url = nexturl[0]['href']
            parseURL
        end
        return
    end

    def parseVideosJson(elements)
        return [] if elements.count == 0
        results = []
        elements.each do |id,data|
            #puts id
            v_id = data['id']
            title = data['title']
            desc  = data['description']
            summary = data['summary']
            len = data['length']
            thumb = data['thumbURL']
            thumb = '' if thumb == nil
            thumb = FixURL(url: thumb)
            cc = nil
           
            video = Video.new(id: v_id, title: title, desc: desc, summary: summary, duration: len, thumb: thumb, cc: cc)
            data['downloads'].each do |item|
                quality = item['quality']
                link = item['link']

                ### calculate subtitles from video path
                if cc == nil
                    cc = link
                    cc_idx = cc.rindex('/')
                    if cc_idx != nil
                        # some id's have -eng at the end...
                        better_id = v_id.gsub(/-eng$/,'')
                        cc = cc[0..cc_idx] + "#{better_id}.xml"
                        cc = cc.gsub("images/videos","dfxp")
                        cc = apply_subtitles_hacks( cc )
                        video.update_subtitles(cc)
                    end
                end

                # if downloaded_video_dir is present then we need to only show
                # videos we've already downloaded.  So, skip any video not already downloaded
                next if DOWNLOADED_VIDEO_DIR != nil and not video_already_downloaded?( link )
                size = item['size']
                quality = FixQuality(title,quality)
                video.add(quality: quality, url: link, size: size)
                $unique_videos[link] = {quality: quality, size: size}
            end
        
            # skip videos with no streams
            next if video.streams.count == 0

            # If we have a known bad subtitle URL remove it
            if $blacklisted_URLs[cc] != 0
                cc = ''
                video.update_subtitles(cc)
            end

            # get subtitles regardless so we can make sure they're correct
            if cc != '' and not subtitles_already_downloaded?( cc )
                PrettyPrintNewline "Downloading missing subtitles: #{cc}"
                download_subtitles( cc ) 
            end

            # add the video to the list
            results << video
        end

        return results
    end

    def parseEntryJson(elements)
        return [] if elements.count == 0
        results = []
        elements.each do |id,data|
            if id == 'videos'
                results = parseVideosJson(data)
            end
        end
        return results
    end

    def to_xml
        return "" if @video_count == 0
        return "" if @smallest_size == 0

        str = "<category title='#{HTMLEntities.new.encode(@title)}' subtitle='Videos: #{@video_count}' img='#{@img}'>"
        @entries.each do |item|
            str += item.to_xml
        end
        if @videos.count > 0
            str += "<rss><channel><title/><description/>\n"
            @videos.each do |video|
                str += video.to_xml
            end
            str += "</channel></rss>"
        end
        return str + "</category>\n"
    end

    #instance method
    def to_glancy( quality )
        return "" if @largest_size == 0
        xml = "<category name='#{HTMLEntities.new.encode(@title)}' thumbnail='#{@img}'>"
        @entries.each do |item|
            xml += item.to_glancy( quality )
        end
        @videos.each do |video|
            xml += video.to_glancy_videoref( quality )
        end

        return xml + "</category>"
    end

    #class method
    def self.to_glancy_library_xml( entries, quality ) #array of entries
        ####return nil if entries.class != :array
        xml = "<library name=\"LDS Media\"><categories>"
        $glancy_videos = {}
        entries.each do |entry|
            xml += entry.to_glancy( quality )
        end

        xml += "</categories><videos>"
        $glancy_videos.each do |id,videoarr|
            xml += Video.to_glancy_video( videoarr[0], videoarr[1] )
        end
        
        return xml + "</videos></library>"
    end

end


def do_glancy_update
    FileUtils::mkdir_p CONTENT_DIR_PREFIX

    print "Reading input files"
    a = MediaLibraryEntry::getList
    begin
        a.parseURL
#    rescue
#        puts "ABORTING EARLY DUE TO ERRORS!"
    end

    puts "\nDone reading input files"

    puts "There are #{a.video_count} videos spanning #{$unique_videos.count} URLs"
    xml = "<categories>" + a.to_xml + "</categories>"
    WriteToFile(OUTPUT_DIR_PREFIX + "medialibrary.xml",xml)

    sizes_per_quality = Hash.new(0)

    # prepopulate the order
    sizes_per_quality["1080p"] = 0
    sizes_per_quality["720p"] = 0
    sizes_per_quality["480p"] = 0
    sizes_per_quality["360p"] = 0

    counts = Hash.new(0)
    #calc size of each quality as-is
    # this differs from the number we really want because some videos
    # are only in a specific size.  (e.g., the 480p quality is smaller than
    # the 360p because there are only a few 480p vids.  Since we want all available
    # videos preferring our chosen size then it should be 360 < 480 < 720 < 1080
    $unique_filenames = Hash.new(0)
    $unique_videos.each do |url,video|
        sizes_per_quality[video[:quality]] += video[:size].to_i
        counts[video[:quality]] += 1
        #sometimes the download URL can be nil / '' if the video isn't downloadable... like ASL Primary Songs
        next if url == nil or url == ''
        # get download filename
        filename = url[(url.rindex('/')+1)..-1]
        $unique_filenames[filename] += 1
    end

    if $unique_videos.count == $unique_filenames.count
        puts "Download filenames are UNIQUE!"
    else
        puts "WARNING:  Download filename collision:"
        $unique_filenames.each do |id,count|
            next if count == 1
            puts "   #{count}: #{id}"
        end
    end

    glancy_rss = "<?xml version=\"1.0\" encoding=\"utf-8\"?>
    <rss version=\"2.0\">
      <channel>
        <title>LDS Media Library as of #{Date.today.to_s}</title>
        <link>http://www.lds.org/media-library</link>
        <description>Media Library for The Church of Jesus Christ of Latter-day Saints</description>
        <copyright>&#169; 2014 by Intellectual Reserve, Inc. All rights reserved.</copyright>\n"

    sizes_per_quality.each do |quality,size|
        # print size of just videos of this quality
        puts "#{quality}: #{size} MB in #{counts[quality]} videos"
        xml = MediaLibraryEntry.to_glancy_library_xml(a.entries,quality.to_i)
        xmlname = "medialibrary_rss_#{quality}.xml"
        WriteToFile(OUTPUT_DIR_PREFIX + xmlname,xml)

        size = 0  # okay now print size of library including other vids we need to have to make a full library
        $glancy_videos.each do |id,videoarr|
            size += videoarr[1].size
        end

        glancy_rss += "<item>
          <title>Media Library #{quality}</title>
          <link>#{HOSTING_URL}/#{xmlname}</link>
          <description>#{(size/1000.0).round(1)} GB</description>
          </item>\n"
    end

    glancy_rss += "</channel></rss>"
    WriteToFile(OUTPUT_DIR_PREFIX + "medialibrary_rss.xml",glancy_rss)
    print_and_save_download_stats

end # do_glancy_update

def do_glancy_export
    FileUtils::mkdir_p CONTENT_DIR_PREFIX
    FileUtils::mkdir_p DOWNLOADED_SUBTITLES_DIR

    print "Reading input files"
    # parse the video list
    a = MediaLibraryEntry::getList
    a.parseURL # skip vids we don't have

    puts "\nDone reading input files"
    puts "There are #{a.video_count} videos spanning #{$unique_videos.count} URLs"
    xml = "<categories>"
    # break out a's entries like this to get rid of the extra screen click
    a.entries.each do |entry|
        xml += entry.to_xml
    end
    xml += "</categories>"
    WriteToFile(OUTPUT_DIR_PREFIX + "medialibrary_downloaded.xml",xml)

    print_and_save_download_stats


end # do_glancy_export

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

def apply_subtitles_hacks( url )
    return '' if url.include?("magazines/one-in-a-million/")
    url = url.gsub("http://media2.ldscdn.org/assets","http://media.ldscdn.org/dfxp")
    url = url.gsub("/dfxp/scripture-stories/","/dfxp/scripture-and-lesson-support/")
    return url
end
    

#############################################
#############################################

#  Where the "main" function begins

$downloaded_thumbnail_count = 0
$missing_thumbnail_count = 0
$downloaded_subtitles_count = 0
$missing_subtitles_count = 0

def printUsage
    puts "Please specify 'update', 'export', or 'glancy_update'"
    puts "   update database_name (language id)"
    puts "   export database_name dirname"
    puts "   glancy_update video_directory"
    exit
end

if ARGV.count < 2
    printUsage
end

if ARGV[0] == 'update'
    printUsage if ARGV.count < 2
    lang_id = 0
    lang_id = ARGV[2].to_i if ARGV.count == 3
    DoUpdateXML(ARGV[1],lang_id)

elsif ARGV[0] == 'export'
    printUsage if ARGV.count != 3
    DoExport(ARGV[1],ARGV[2])

elsif ARGV[0] == 'glancy_update'
    printUsage if ARGV.count != 2
    load_blacklisted_urls
    DOWNLOADED_VIDEO_DIR = nil  # nil because we want to create XML for all vids
    DOWNLOADED_THUMBNAIL_DIR = "#{ARGV[1]}/thumbnails"
    DOWNLOADED_SUBTITLES_DIR = "#{ARGV[1]}/subtitles"
    PARSE_MODE = :UPDATE
    do_glancy_update
else
    printUsage
end

