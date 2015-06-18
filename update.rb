# encoding: utf-8
require_relative 'common'
require 'zlib'          # for Zlib
require 'fileutils'     # for mkdir_p
require 'json'          # for JSON
require 'htmlentities'  # for HtmlEntities
require 'time'          # for Time

# the subdirectory we want to store our results in
time = Time.now
OUTPUT_DIR_PREFIX = "medialibrary_#{time.year}_#{time.month}_#{time.day}/"
CONTENT_DIR_PREFIX = OUTPUT_DIR_PREFIX + "content/"
RSS_DIR_PREFIX = OUTPUT_DIR_PREFIX + "rss/"
ROKU_CHANNEL_DIR_PREFIX = OUTPUT_DIR_PREFIX + "roku/"

FileUtils::mkdir_p CONTENT_DIR_PREFIX
FileUtils::mkdir_p RSS_DIR_PREFIX
FileUtils::mkdir_p ROKU_CHANNEL_DIR_PREFIX

ROKU_HOSTING_URL  = "http://paulwhiting.github.io/GospelLibraryVideos/roku_channel"
RSS_HOSTING_URL  = "http://paulwhiting.github.io/GospelLibraryVideos/rss"

require 'sqlite3'
COVER_ART_URL = "http://broadcast3.lds.org/crowdsource/Mobile/GospelStudy/production/v1"
COVERS_SHOW_EMPTY = true
IGNORE_OBSOLETE = true


$book_cache = {}

def UpdateBookEntryDatabase(db,catalog_id,book_id,xml)
    db.execute( "INSERT or replace INTO books ( catalog_id, book_id, content ) VALUES ( ?, ?, ? )", [catalog_id, book_id, xml])
end

def TreeifyBookEntries(entries,param_id)
    results = []
    entries.each do |entry|
        next if entry.parent_id != param_id
        entry.setChildren( TreeifyBookEntries(entries,entry.id) )
        results << entry
    end
    return results
end

def getVideos(url,filename)
    zbook = OpenURL(url,filename)
    filename_sql = filename + '.sql'

    return [] if zbook == nil

    sql = Zlib::Inflate.inflate(zbook)
    WriteToFile(filename_sql,sql)

    entries = []
    dbname = filename_sql
    db = SQLite3::Database.new( dbname )
    results = db.execute( "select id,parent_id,title,subtitle,short_title,content,uri from node" )
    results.each do |row|
        next if not row
        params = {  id: row[0],
                    parent_id: row[1],
                    title: row[2],
                    subtitle: row[3],
                    short_title: row[4],
                    content: row[5],
                    uri: row[6] }

        entry = BookEntry.new(params)

        #  process the related media table
        #  These should be grouped into one media item
        #  [:mp3, :mp4].each do |format|
            skipped_video = Hash.new(nil)
            has_audio = false
            medias = db.execute( "select size, width, height, name, link, type from media where uri = :uri", uri: params[:uri] )
            if medias.count > 0
                video_title = params[:title]
                video = Video.new(title: video_title)
                medias.each do |row|
                    p2 = {   size: row[0],
                            width: row[1],
                            height: row[2],
                            name: row[3],
                            link: row[4],
                            type: row[5] }

                    if p2[:type] == 'jpg'
                        video.update_thumbnail(p2[:link])
                        next
                    elsif p2[:type] == 'pdf'
                        next
                    end

                    url = p2[:link]
                    bytes = p2[:size].to_i
                    duration = ''
                    if p2[:type] == 'mp3'
                        quality = 'mp3'
                        has_audio = true
                    elsif p2[:type] == 'mp4'
                        quality = p2[:height].to_i
                        # prefer standard qualities over non-standard ones because there are a dozen we don't need usually
                        if not [1080,720,480,360].include?( quality )
                            skipped_video[quality] = bytes if skipped_video[quality] == nil or skipped_video[quality] < bytes
                            next
                        end
                        quality = FixQuality(video_title,quality)
                    else
                        PrettyPrintNewline("Unsupported type: #{p2[:type]}")
                        next
                    end  # quality
                    video.add(url: url, quality: quality, size: bytes, duration: duration)
                    $unique_videos[url] = {quality: quality, size: bytes}
                end  # each medias

                # if we have no streams but skipped some then try again
                # OR if we only have an audio stream then also try again
                if ((video.streams.count == 0 and skipped_video.count > 0) or (video.streams.count == 1 and has_audio))
                    # find the best video to use
                    best = skipped_video.sort[-1]
                    best_q = best[0]
                    best_bytes = best[1]
                    medias.each {|row|
                        p2 = {   size: row[0],
                                width: row[1],
                                height: row[2],
                                name: row[3],
                                link: row[4],
                                type: row[5] }

                        url = p2[:link]
                        bytes = p2[:size].to_i
                        duration = ''
                        quality = p2[:height].to_i
                        next if quality != best_q and bytes != best_bytes and type != 'mp4'
                        quality = FixQuality(video_title,quality)
                        video.add(url: url, quality: quality, size: bytes, duration: duration)
                        $unique_videos[url] = {quality: quality, size: bytes}
                    }
                end
                entry.add_media(video) if video.streams.count > 0
            end  # if media count > 0
        #end  # each format

        # process the content table
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
                if video_title
                    params[:title] = video_title
                end
                video = Video.new(title: params[:title])
                src = item.children.css("source[data-container=mp4]")
                skipped_video = Hash.new(0)
                src.each {|s|
                    bytes = s['data-sizeinbytes'].to_i
                    url = s['src']
                    duration = s['data-durationms'].to_i / 1000
                    quality = s['data-height'].to_i
                    if not [1080,720,480,360].include?( quality )
                        skipped_video[quality] = bytes if skipped_video[quality] < bytes
                        next
                    end
                    quality = FixQuality(params[:title],quality)
                    video.add(url: url, quality: quality, size: bytes, duration: duration)
                    $unique_videos[url] = {quality: quality, size: bytes}
                }

                if video.streams.count == 0 and skipped_video.count > 0
                    # raise "No videos found for #{params[:title]} but we skipped some (#{skipped_video})!"
                    # instead of throwing an error find the best video to use
                    best = skipped_video.sort[-1]
                    best_q = best[0]
                    best_bytes = best[1]
                    src.each {|s|
                        bytes = s['data-sizeinbytes'].to_i
                        url = s['src']
                        duration = s['data-durationms'].to_i / 1000
                        quality = s['data-height'].to_i
                        next if quality != best_q and bytes != best_bytes
                        quality = FixQuality(params[:title],quality)
                        video.add(url: url, quality: quality, size: bytes, duration: duration)
                        $unique_videos[url] = {quality: quality, size: bytes}
                    }
                end

                entry.add_media(video)
            }
        end

        entries << entry
    end

    return entries
end

class BookEntry
    attr_reader :id
    attr_reader :parent_id
    attr_reader :media

    def initialize( params )
        @id = params[:id]
        @parent_id = params[:parent_id]
        @title = params[:title]
        # encode the title so we can later compare against video titles when combining children
        @title = HTMLEntities.new.encode(@title) if @title != nil
        @subtitle = params[:subtitle]
        @short_title = params[:short_title]
        @cover_art = params[:cover_art]
        if @cover_art == nil
            @cover_art = ''
        else
            @cover_art = @cover_art.gsub(/{\d*}/,'@2x')
        end
        @children = []
        @media = []
        @video_count = 0
        @audio_count = 0
    end

    def setChildren(children)
        @children = children
    end

    def add_media( media )
        @media << media
        @video_count += 1 if media.has_video?
        @audio_count += 1 if media.has_audio?
    end

    def calculateVideoCount
        @children.each do |item|  # item is BookEntry
            @video_count += item.calculateVideoCount
        end

        return @video_count
    end

    def calculateAudioCount
        @children.each do |item|  # item is BookEntry
            @audio_count += item.calculateAudioCount
        end

        return @audio_count
    end

    #  Something is combinable if it has (zero or) just one video
    #  AND the same title
    def combinable?
        if @media.count == 0 and @children.count == 0
            return true
        elsif @media.count == 1
            #if @title == @media[0].title
                #puts "#{@title} == #{@media[0].title}"
            #    puts "combinable true for #{@title}"
            #    return true
            #else
            #    puts "#{@title} != #{@media[0].title}"
            #end
        end

        #puts "combinable false for #{@title}"
        return false
    end
        
    #  The parent assumes all media of its children
    def combineSimilarChildren
        #puts "Combining children for BookEntry #{@title}"
        combinable = 0
        @children.each do |item|  # item is BookEntry
            item.combineSimilarChildren  # recurse to all children
            combinable += 1 if item.combinable?
        end

        puts "#{combinable} is or isn't #{@children.count} for #{@title}"
        if combinable == @children.count
            @children.each do |item|
                @media.concat( item.media )
                @video_count += item.calculateVideoCount
                @audio_count += item.calculateAudioCount
            end
            @children = []
        end
    end

    def get_media_xml
        xml = ''

        if @media.count > 0
            xml = "<rss><channel>"
            @media.each do |item|
                xml += item.to_xml
            end
            xml += "</channel></rss>"
        end

        return xml
    end

    def to_xml
        return "" if @video_count == 0 and @audio_count == 0
        str = "<category title='#{HTMLEntities.new.encode(@title)}' subtitle='Videos: #{@video_count}; Audio: #{@audio_count}'>"  # showAsList='1'>"
        @children.each do |item|
            str += item.to_xml
        end

        str += get_media_xml
        return str + "</category>\n"
    end

#    def to_glancy( quality )
#        return "" if @video_count == 0
#        xml = "<category name='#{HTMLEntities.new.encode(@title)}' thumbnail='#{@img}'>"
#        @children.each do |item|
#            xml += item.to_glancy( quality )
#        end
#        @media.each do |item|
#            xml += item.to_glancy_videoref( quality )
#        end
#
#        return xml + "</category>\n"
#    end
end



class CatalogEntry < BookEntry
    def initialize( catalog_id, id, name, cover_art )
        super({id: id, title: name, cover_art: cover_art})
        @catalog_id = catalog_id
        
        @url = ""
        @filename = ""
    end

    def setURLInfo(url,filename)
        @url = url
        @filename = CONTENT_DIR_PREFIX + "catentry_#{@catalog_id}_#{filename}"
    end

    def getBookEntries
        books = []
        #if @url != "" and @id == 23637 #... for quick testing hungarian
        #if @url != "" and @id == 24825 #... for quick testing english
        #if @url != "" and @url.include?("Friend") #id == 42769 #... for quick testing english
        #if @url != "" and @url.include?("scriptures.bofm") #id == 42769 #... for quick testing english
        #if @url != "" and @url.include?("youth.learn.yw") #id == 42769 #... for quick testing english
        #if @url != "" and @url.include?("2015") #id == 42769 #... for quick testing english
        if @url != ""
            if not @url.include?(".zbook")
                puts "BAD URL!!!!!  id=#{@id}  name = #{@title}   url=#{@url}"
            end
            if $book_cache[@url]
                puts "Cached URL is #{@url}"
                books = $book_cache[@url]
            else
                puts "New URL is #{@url}"
                entries = getVideos(@url,@filename)
                # result is an array of miscellaneous BookEntries
                # Convert to an array of ordered tree BookEntries
                books = TreeifyBookEntries(entries,0)
                $book_cache[@url] = books
            end
        end

        if @children
            @children.each do |item|
                item.getBookEntries
            end
        end

        # finally lump the books with the children
        # because there really should only be one or the other
        if books.count > 1
            if @children.count > 1
                raise "bad data"  
            else
                @children = books
            end
        end
    end

    def printEntries(indent)
        puts "    "*indent + @title + "(#{url})"
        if @children
            @children.each do |item|
                item.printEntries(indent+1)
            end
        end
    end

    def updateDatabaseXML( db )
        return if @video_count == 0 and @audio_count == 0   # don't do anything if no vids

        if @url != ''
            if @children.count > 0
                str = "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
    <categories>"
                @children.each do |item|   #item is BookEntry
                    str += item.to_xml
                end
                str += "</categories>"
                puts "updating db for #{@catalog_id}, #{@id}"
                UpdateBookEntryDatabase(db,@catalog_id,@id,str)
            else
                xml = "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>"
                rss = get_media_xml
                if rss == ''
                    rss = '<rss><channel/></rss>'
                end
                xml += rss
                puts "updating db for #{@catalog_id}, #{@id}"
                UpdateBookEntryDatabase(db,@catalog_id,@id,xml)
            end
        else
            raise "Invalid data" if @media.count > 0
            @children.each do |item|
                item.updateDatabaseXML( db )
            end
        end
    end

    def to_xml
        return "" if @video_count == 0 and @audio_count == 0
        cover_art = getClosestCoverArt
        str = "<category title='#{HTMLEntities.new.encode(@title)}' subtitle='Videos: #{@video_count}, Audio: #{@audio_count}' url='#{@url != '' ? "#{ROKU_HOSTING_URL}/langs/#{@catalog_id}/books/#{@id}.xml" : ''}'"
        str +=  " img='#{COVER_ART_URL}/#{cover_art}'" if cover_art != ''
        #str += " showAsList='1'"
        str += ">\n"

        @children.each do |child|
            str += child.to_xml
        end

        return str + "</category>\n"
    end

#    def to_glancy( quality )
#        return "" if @video_count == 0 and @audio_count == 0
#        cover_art = getClosestCoverArt
#        xml = "<category name='#{HTMLEntities.new.encode(@title)}'"
#        xml += " thumbnail='#{COVER_ART_URL}/#{cover_art}'" if cover_art != ''
#        xml += ">\n"
#        @children.each do |child|
#            xml += child.to_glancy( quality )
#        end
#        @books.each do |book|
#            xml += book.to_glancy( quality )
#        end
#
#        return xml + "</category>"
#    end

    def getClosestCoverArt
        return @cover_art if @cover_art != '' and (COVERS_SHOW_EMPTY or @video_count > 0 or @audio_count > 0)

        @children.each do |item|    #item is CatalogEntry
            cover = item.getClosestCoverArt
            return cover if cover != '' and (COVERS_SHOW_EMPTY or item.video_count > 0 or @audio_count > 0)
        end

        return ''
    end
end

class Language
    attr_accessor :name
    attr_accessor :id
    attr_accessor :catalog
    attr_accessor :video_count
    attr_accessor :audio_count

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
        @audio_count = 0
    end

    def parseEntryJson(elements)
        return [] if elements.count == 0
        results = []
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
                    result = CatalogEntry.new(@id,id,name,cover_art) #@id is catalog id, id is entry id
                    result.setChildren(subresults)
                    results << result
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
                    result = CatalogEntry.new(@id,id,name,cover_art) #@id is catalog id, id is entry id
                    result.setURLInfo(url,file)
                    result.setChildren(subresults)
                    results << result
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
        @catalog.each do |item|
            item.getBookEntries
        end
    end

    def calculateVideoCount
        @video_count = 0
        @catalog.each do |item|   #item is CatalogEntry
            @video_count += item.calculateVideoCount
        end
    end

    def calculateAudioCount
        @audio_count = 0
        @catalog.each do |item|   #item is CatalogEntry
            @audio_count += item.calculateAudioCount
        end
    end

    def combineSimilarChildren
        puts "Combining children for #{@name}"
        @catalog.each do |item|   #item is CatalogEntry
            item.combineSimilarChildren
        end
    end

    def updateDatabaseXML( db )
        puts "Updating Language #{@id}"
        if @video_count == 0 and @audio_count == 0
            puts "No videos! No audio!  Skipping #{@name} language :("
            return
        end
        str = "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
        <categories>"
        @catalog.each do |item|
            puts "Processing #{id}..."
            item.updateDatabaseXML(db)
            str += item.to_xml
        end 
        str += "</categories>"
        #puts str
        db.execute( "INSERT or replace INTO catalogs ( id, content ) VALUES ( ?, ? )", [@id, str])
    end

    def to_titlepage_xml
        return "" if @video_count == 0 and @audio_count == 0
        cover = getClosestCoverArt
        cover = " img='#{COVER_ART_URL}/#{cover}'" if cover != ''
        
        return "<category title='#{HTMLEntities.new.encode(@name)}' url='#{ROKU_HOSTING_URL}/langs/#{@id}.xml' subtitle='Videos: #{@video_count}, Audio: #{@audio_count}'#{cover}/>"
    end

    def getClosestCoverArt
        @catalog.each do |item|  #item is CatalogEntry
            cover = item.getClosestCoverArt
            return cover if cover != '' and (COVERS_SHOW_EMPTY or item.video_count > 0 or item.audio_count > 0)
        end

        return ''
    end

    def printCatalog
        puts @name
        @catalog.each do |item|
            item.printEntries(1)
        end
    end

#    def to_glancy_library_xml( quality )
#        if @video_count == 0 and @audio_count == 0
#            puts "No videos!  No audio!  Skipping #{@name} language :("
#            return ''
#        end
#
#        xml = "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>"
#        xml += "<library name=\"LDS Media\"><categories>"
#        $glancy_videos = {}
#        @catalog.each do |item|
#            xml += item.to_glancy( quality )
#        end
#
#        xml += "</categories><videos>"
#        $glancy_videos.each do |id,videoarr|
#            xml += Video.to_glancy_video( videoarr[0], videoarr[1] )
#        end
#        
#        return xml + "</videos></library>"
#    end

end


def DoUpdateGL( dbname, requested_id )

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
        $unique_videos = {}
        $unique_filenames = Hash.new(0)
        catalog = language.getCatalogEntries
        language.getBookEntries
        language.combineSimilarChildren
        language.calculateVideoCount
        language.calculateAudioCount

        language.updateDatabaseXML(db)
        langstr += language.to_titlepage_xml
        #common_glancy_output( "GL-#{language.name}", language )
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

#  dbname = filename of the sqlite db the results are stored in
#  dirname = the output directory we're writing to
#  test_prefix_url = a prefix url for testing purposes
def DoExportGL(dbname, dirname, test_prefix_url = nil)

    Dir.mkdir dirname if not Dir.exists?(dirname)

    db = SQLite3::Database.new( dbname )
    stm = db.prepare "SELECT * from catalogs;"
    rows = stm.execute

    rows.each do |row|
        id = row[0]
        xml = row[1]
        xml.gsub!(ROKU_HOSTING_URL,test_prefix_url) if test_prefix_url
        filename = "#{dirname}/langs/#{id}.xml"
        outdir = File.dirname( filename )
        FileUtils::mkdir_p outdir if not Dir.exists?( outdir )
        f = File.open(filename,"wb")
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
        xml.gsub!(ROKU_HOSTING_URL,test_prefix_url) if test_prefix_url
        filename = "#{dirname}/langs/#{lang_id}/books/#{book_id}.xml"
        outdir = File.dirname( filename )
        FileUtils::mkdir_p outdir if not Dir.exists?( outdir )
        f = File.open(filename,"wb")
        f.write xml
        f.close
    end

    stm.close
    db.close
end

#############################################
#############################################

#  Where the Media Library / RSS parser code begins

ROKU_USB_VIDEO_PREFIX = "ext1:/LDS Media"
ROKU_USB_THUMBNAIL_PREFIX = "ext1:/LDS Media/thumbnails"
ROKU_USB_SUBTITLES_PREFIX = "ext1:/LDS Media/subtitles"

def durationStrToInt( duration )
    t1 = Time.parse( "2015-01-01 00:00:00" )

    begin
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
    rescue
        PrettyPrintNewline("ERROR calculating duration from #{duration}")
        return 0
    end
end
    
class VideoStream
    attr_accessor :url
    attr_accessor :quality
    attr_accessor :size

	def initialize( params )
        @url = params[:url]
        @url = @url.gsub("?download=true","") if @url
        @quality = params[:quality]
        @size = params[:size].to_i
        @size = 0 if @size == nil
    end

    def to_xml
        "<content url='#{@url}' height='#{@quality}'/>\n"
    end
end

def FixURL( params )
    params[:title] = '' if params[:title] == nil

    # warn if improper slashes are used
    if params[:url].include?('\\')
        PrettyPrintNewline "WARNING: URL contains '\\' - #{params[:url]}"
        params[:url].gsub!('\\','/')
    end

    # warn if improper whitespace is present
    nowhitespace = params[:url].strip
    if nowhitespace != params[:url]
        PrettyPrintNewline "WARNING: URL contains extra whitespace - #{params[:url]}"
        params[:url] = nowhitespace
    end

    # warn if encoded whitespace is present
    if params[:url].include?('%20')
        PrettyPrintNewline "WARNING: URL contains '%20' - #{params[:url]}"
    end

    if params[:title] == "Step Two: Hope" and params[:quality].to_i == 1080 and params[:url] == "http://media2.ldscdn.org/assets/welfare/lds-addiction-recovery-program-twelve-step-video-series/2012-12-001-step-one-honesty-1080p-eng.mp4"
        PrettyPrintNewline "Fixing Addiction Step Two URL..."
        return "http://media2.ldscdn.org/assets/welfare/lds-addiction-recovery-program-twelve-step-video-series/2012-12-002-step-two-hope-1080p-eng.mp4"

    elsif params[:url] == "/pages/mormon-messages/images/voice-of-the-spirit-mormon-message-138x81.jpg"
        PrettyPrintNewline "Fixing Voice of the Spirit URL..."
        return "http://media.ldscdn.org/images/videos/mormon-channel/mormon-messages-2010/2010-08-16-voice-of-the-spirit-192x108-thumb.jpg"

    elsif params[:title].include?('Linda S. Reeves') and params[:url].include?('2014-04-0010-president-thomas-s-monson-1080p')
        PrettyPrintNewline "Fixing Linda S. Reeves URL..."
        return "media2.ldscdn.org/assets/general-conference/april-2014-general-conference-highlights/2014-04-0050-linda-s-reeves-1080p-spa.mp4"

    elsif params[:title].include?('Henry B. Eyring') and params[:quality].to_i == 1080 and params[:url] == "http://media2.ldscdn.org/assets/general-conference/april-2014-general-conference-highlights/2014-04-0080-elder-russell-m-nelson-360p-spa.mp4"
        PrettyPrintNewline "Fixing Henry B. Eyring URL..."
        return "http://media2.ldscdn.org/assets/general-conference/april-2014-general-conference-highlights/2014-04-0070-president-henry-b-eyring-1080p-spa.mp4"

    elsif params[:title].include?('Henry B. Eyring') and params[:quality].to_i == 360 and params[:url] == "http://media2.ldscdn.org/assets/general-conference/april-2014-general-conference-highlights/2014-04-0080-elder-russell-m-nelson-1080p-spa.mp4"
        PrettyPrintNewline "Fixing Henry B. Eyring URL..."
        return "http://media2.ldscdn.org/assets/general-conference/april-2014-general-conference-highlights/2014-04-0070-president-henry-b-eyring-360p-spa.mp4"

    end
    if params[:url].start_with?("https:")
        return params[:url].gsub("https:","http:")
    elsif params[:url].start_with?('/') # if it doesn't start with http then assume it's a relative URL instead of absolute
        #PrettyPrintNewline "Fixing URL to be absolute..."
        return "http://www.lds.org" + params[:url]
    end
    return params[:url]
end

def FixQuality( title, quality )
    q = quality.to_i
    if q != nil
        case q
        when 1080
            return "1080p"
        when 720
            return "720p"
        when 480
            return "480p"
        when 360
            return "360p"
        end
    end

    case quality
    when "1080p", "720p", "360p", "480p"
        # this is the default good enough case
        return quality
    when "1080", "1080P", "1080 p", "Large", "Large video"
        PrettyPrintNewline "Fixing quality '#{quality}' to 1080p for #{title}"
        return "1080p"
    when "720", "720P", "720 p", "Medium", "Medium video"
        PrettyPrintNewline "Fixing quality '#{quality}' to 720p for #{title}"
        return "720p"
    when "360P", "360 p", "Small", "Small video"
        PrettyPrintNewline "Fixing quality '#{quality}' to 360p for #{title}"
        return "360p"
    when "Audio Description", "MP3", "mp3"
        return "mp3"
    else
        PrettyPrintNewline "Fixing unknown quality '#{quality}' to 360p for #{title}"
        return "360p"
    end
end

def NormalizeParams( params )
    params[:title] = HTMLEntities.new.encode(params[:title]) if params[:title] != nil
    params[:duration] = durationStrToInt(params[:durationstr]) if params[:durationstr] != nil
    params[:summary] = HTMLEntities.new.encode(params[:summary]) if params[:summary] != nil
    params[:desc] = HTMLEntities.new.encode(params[:desc]) if params[:desc] != nil
    params[:quality] = FixQuality( params[:title], params[:quality] ) if params[:quality] != nil
    params[:thumb] = FixURL( title: params[:title], url: params[:thumb], quality: params[:quality] ) if params[:thumb] != nil
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

    # expected url, quality, size
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
        if params[:duration] and @duration == nil
            @duration = params[:duration]
        end
        @streams << stream
    end

    def update_subtitles( cc )
        @closedcaptions = cc
    end

    def update_thumbnail( thumb )
        @thumbnail = thumb
    end

    def has_audio?
        @streams.each do |stream|
            return true if stream.quality == 'mp3'
        end

        return false
    end

    def has_video?
        @streams.each do |stream|
            return true if stream.quality != 'mp3'
        end

        return false
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

    def get_rss_stream( quality )
        return "" if smallest_size == 0
        found_quality = 0
        found_stream = nil
        smallest_stream = nil
        @streams.each do |stream|
            q = stream.quality.to_i
            # find the smallest video equal to or less than the quality
            if q > found_quality and q <= quality
                found_quality = q
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

    def to_rss_videoref( quality )
        return "" if @smallest_size == 0
        stream = get_rss_stream( quality )
        if stream != nil
            found_url = stream.url
            # make sure if we have a duplicate video it has the right name
            if $rss_videos[found_url] != nil
                v2 = $rss_videos[found_url][0].title
                if v2 != @title
                    puts "WARNING:  URL title mismatch:  #{v2}  !=  #{@title}\nfor video #{found_url}"
                end
            end
            $rss_videos[found_url] = [self,stream]
            return "<videoref ref=\"#{found_url}\"/>\n" 
        end
        return ""
    end

    def self.to_rss_video( video, stream )
        return "" if video.smallest_size == 0
        if stream != nil
            return "<video id=\"#{stream.url}\" name=\"#{video.title}\" thumbnail=\"#{video.thumbnail}\" url=\"#{stream.url}\"/>\n"
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

    def initialize( params )
        @title = params[:title]
        @url = params[:url]
        @img = params[:img]
        @img = "" if @img == nil
        @img.gsub!("https","http")
        @img.gsub!(" ","%20")
        @video_count = 0
        @entries = []
        @videos = []
        @smallest_size = 0
        @largest_size = 0
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
            if img.start_with?('/')
                #PrettyPrintNewline "Fixing URL to be absolute..."
                img = "http://www.lds.org" + img
            end
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
            begin
                elements = JSON.parse(text)
                vids = parseEntryJson(elements)
            rescue => error
                PrettyPrintNewline "EXCEPTION parsing JSON on page #{@url}  --  #{error.message}"
                puts "Backtrace:\n\t#{error.backtrace.join("\n\t")}"
                vids = []
            end
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

    def parseMusicURL
        filename = CONTENT_DIR_PREFIX + @url.gsub(/[:\/?&=]/,'_')
        data = OpenURL(@url, filename)
        html = Nokogiri::HTML(data) 

        # The good stuff is stored in <div id="primary">
        categories = html.css("div#primary ul[class='grid clearfix'] li")
        categories.each {|item|
            p name = item.children.css("a span").text.strip
            url = item.children.css("a")[0]['href'].strip
            mle = MediaLibraryEntry.new(title: name,url: url, img: nil)
            mle.parseMusicURL if url
            @smallest_size += mle.smallest_size
            @largest_size += mle.largest_size
            @video_count += mle.video_count
            @entries << mle
        }
        categories = html.css("div#primary ul[class='grid'] li")
        categories.each {|item|
            p name = item.children.css("a span").text.strip
            url = item.children.css("a")[0]['href'].strip
            mle = MediaLibraryEntry.new(title: name,url: url, img: nil)
            mle.parseMusicURL if url
            @smallest_size += mle.smallest_size
            @largest_size += mle.largest_size
            @video_count += mle.video_count
            @entries << mle
        }

        # find the one that has the audio data... that's the one we want
        scripts = html.css("script")
        scripts.each {|item|
            text = item.text.strip
            next if not text.start_with? "var jsonPlaylist ="
            start = 19
            last = text.index('};')
            text = text.slice(start..last)
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
           
            video = Video.new(id: v_id, title: title, desc: desc, summary: summary, durationstr: len, thumb: thumb, cc: cc)
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
                        if $cached_subtitles[better_id]
                            cc = $cached_subtitles[better_id]
                            #puts "found cached subtitle #{cc}"
                        else
                            #puts "WARNING: no cached subtitle for #{better_id}"
                            cc = cc[0..cc_idx] + "#{better_id}.xml"
                            cc = cc.gsub("images/videos","dfxp")
                            cc = apply_subtitles_hacks( cc )
                        end
                    end
                    video.update_subtitles(cc) if cc != nil
                end

                # if downloaded_video_dir is present then we need to only show
                # videos we've already downloaded.  So, skip any video not already downloaded
                next if DOWNLOADED_VIDEO_DIR != nil and not video_already_downloaded?( link )
                size = item['size']
                if size.to_i == 0
                  if link == nil or link == ""
                    PrettyPrintNewline "When detecting size the URL is empty for #{title}"
                  else
                    size = $cached_file_sizes[link].to_f
                    if size > 0
                      PrettyPrintNewline "WARNING: Using cached video download size (#{size} MB) for #{link} on page #{@url}"
                    else
                      if $detected_file_sizes[link] > 0
                        size = $detected_file_sizes[link]
                      else
                        size = get_file_download_size( link ) / 1000000.0  # we want size in MB not bytes
                        $detected_file_sizes[link] = size
                        PrettyPrintNewline "WARNING: Video download size is zero for #{link} on page #{@url} but it was detected to be #{size.round(2)} MB"
                      end
                    end
                  end
                end
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

    def parseMusicJson(elements)
        return [] if elements.count == 0
        results = []
        elements.each do |data|
            #p data
            v_id = data['name']
            title = data['name']
            desc  = data['book']
            summary = data['book']
           
            video = Video.new(id: v_id, title: title, desc: desc)
            quality = nil
            # mp3 is music and words.  same as url
            # alturl is music only
            # video1 is mp4, video2 is wmv
            ['url','alturl','video1'].each do |type|
              link = data[type]
              next if not link
              quality = 'mp3' if type == 'url' or type == 'alturl'
              quality = '360p' if type == 'video1'

              video.add(url: link)
              $unique_videos[link] = {quality: quality, size: 0}
            end
        
            # skip videos with no streams
            next if video.streams.count == 0

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
            if id == 'playlist'
              data.each do |id2,data2|
                if id2 == 'list'
                  results = parseMusicJson(data2)
                end
              end
            end
        end
        return results
    end

    def to_xml
        #puts "video count is #{@video_count}"
        return "" if @video_count == 0
        #we may have valid vids with no size info #return "" if @smallest_size == 0

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

    def to_rss( quality )
        return "" if @largest_size == 0
        xml = "<category name='#{HTMLEntities.new.encode(@title)}' thumbnail='#{@img}'>"
        @entries.each do |item|
            xml += item.to_rss( quality )
        end
        @videos.each do |video|
            xml += video.to_rss_videoref( quality )
        end

        return xml + "</category>"
    end

    def to_rss_library_xml( quality ) #array of entries
        xml = "<library name=\"LDS Media\"><categories>"
        $rss_videos = {}
        @entries.each do |entry|
            xml += entry.to_rss( quality )
        end

        xml += "</categories><videos>"
        $rss_videos.each do |id,videoarr|
            xml += Video.to_rss_video( videoarr[0], videoarr[1] )
        end
        
        return xml + "</videos></library>"
    end

end


# input should be something like:
# {language: "English", url: "https://.../..."}

def do_update( params = {} )
    if params[:title] == nil or params[:url] == nil
        puts "Error:  please specify an input title and url"
        return
    end

    title = params[:title]
    url = params[:url]
    filename = params[:filename]
    filename = title if filename == nil

    $unique_videos = {}
    $unique_filenames = Hash.new(0)


    print "Reading input files for #{title}"
    a = MediaLibraryEntry.new(title: title, url: url)
    if title == "Music"
      a.parseMusicURL
    else
      a.parseURL
    end

    puts "\nDone reading input files"


    # shed the outer wrapper and create the xml for the roku
    innerentry = a # a.entries[0]
    xml = "<categories>"
    a.entries.each do |e|
        xml += e.to_xml
    end
    xml += "</categories>"
    WriteToFile(ROKU_CHANNEL_DIR_PREFIX + "medialibrary_#{filename}.xml",xml)

    common_rss_output( filename, title, a )
end

def common_rss_output( filename, title, a )
    puts "There are #{a.video_count} videos spanning #{$unique_videos.count} URLs"
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
    $unique_videos.each do |url,video|
        sizes_per_quality[video[:quality]] += video[:size].to_i
        counts[video[:quality]] += 1
        #sometimes the download URL can be nil / '' if the video isn't downloadable... like ASL Primary Songs
        next if url == nil or url == ''
        # get download filename
        index = url.rindex('/')
        if index == nil
            f = url
        else
            f = url[(index+1)..-1]
        end
        $unique_filenames[f] += 1
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

    rss = ""

    sizes_per_quality.each do |quality,size|
        # print size of just videos of this quality
        puts "#{quality}: #{size} MB in #{counts[quality]} videos"
        xml = a.to_rss_library_xml(quality.to_i)
        xmlname = "medialibrary_rss_#{filename}_#{quality}.xml"
        WriteToFile(RSS_DIR_PREFIX + xmlname,xml)

        size = 0  # okay now print size of library including other vids we need to have to make a full library
        $rss_videos.each do |id,videoarr|
            size += videoarr[1].size
        end

        rss += "<item>
          <title>#{title} Media Library #{quality}</title>
          <link>#{RSS_HOSTING_URL}/#{xmlname}</link>
          <description>#{(size/1000.0).round(1)} GB</description>
          </item>\n"
    end

    WriteToFile(RSS_DIR_PREFIX + "medialibrary_rss_#{filename}.xml",rss)
    print_and_save_download_stats

end # do_update

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

    if $detected_file_sizes.count > 0
        puts "Detected file size count: #{$detected_file_sizes.count}. Refer to url_detected_sizes.txt for more information."
        detections = ""

        $detected_file_sizes.each do |url,size|
            detections += "#{size} #{url}\n"
        end
        WriteToFile("url_detected_sizes.txt",detections)
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

#################################################
#  Where the "main" function begins

$downloaded_thumbnail_count = 0
$missing_thumbnail_count = 0
$downloaded_subtitles_count = 0
$missing_subtitles_count = 0

def printUsage
    puts "Please specify 'update_GL', 'export_GL', or 'update'"
    puts "   update_GL database_name (language id)"
    puts "   export_GL database_name dirname (test_url_prefix)"
    puts "   update video_directory"
    exit
end

if ARGV.count < 2
    printUsage
end

if ARGV[0].downcase == 'update_gl'
    #  This option downloads all the Gospel Library database files, processes
    #  them and saves the results to a SQL database.
    printUsage if ARGV.count < 2
    lang_id = 0
    lang_id = ARGV[2].to_i if ARGV.count == 3
    DoUpdateGL(ARGV[1],lang_id)

elsif ARGV[0].downcase == 'export_gl'
    #  This option exports our SQL database to a bunch of files on disk for
    #  serving up as static web pages
    printUsage if ARGV.count < 3
    if ARGV.count == 3
        DoExportGL(ARGV[1],ARGV[2])
    else
        DoExportGL(ARGV[1],ARGV[2],ARGV[3])
    end

elsif ARGV[0].downcase == 'update'
    #  This update option scrapes the web pages avoiding blacklisted links
    #  which are known bad... mostly from our guessing subtitle URLs.

    printUsage if ARGV.count != 2
    load_blacklisted_urls
    load_cached_file_sizes
    load_cached_subtitles

    DOWNLOADED_VIDEO_DIR = nil  # nil because we want to create XML for all vids
    DOWNLOADED_THUMBNAIL_DIR = "#{ARGV[1]}/thumbnails"
    DOWNLOADED_SUBTITLES_DIR = "#{ARGV[1]}/subtitles"

    # boilerplate rss header information
    rss = "<?xml version=\"1.0\" encoding=\"utf-8\"?>
    <rss version=\"2.0\">
      <channel>
        <title>LDS Media Library as of #{Date.today.to_s}</title>
        <link>http://www.lds.org/media-library</link>
        <description>Media Library for The Church of Jesus Christ of Latter-day Saints</description>
        <copyright>&#169; 2014 by Intellectual Reserve, Inc. All rights reserved.</copyright>\n"


    # the music URL is special
    ENGLISH_MUSIC_URL  = "https://www.lds.org/music/library"
    GENERIC_URL  = "https://www.lds.org/media-library/video/categories?lang="

    # for each filename/title/URL tag download all the web pages and scrape them
    [
      ["ASL", "American Sign Language (ASL)", "eng&clang=ase"],
      ["Deutsch", "Deutsch", "deu"],
      ["English", "English", "eng"],
      ["French", "Français", "fra"],
      ["Italiano", "Italiano", "ita"],
      ["Japanese", "日本語", "jpn"],
      ["Korean", "한국어", "kor"],
      ["Portuguese", "Português", "por"],
      ["Russian", "Русский", "rus"],
      ["Spanish", "Español", "spa"],
      ["Music", "Music", ""],
    ].each do |threesome|
        filename, title, tag = threesome
        if title != "Music"
            do_update(filename: filename, title: title, url: GENERIC_URL + tag)
        else
            do_update(title: "Music", url: ENGLISH_MUSIC_URL)
        end

        #  web scraping results in many files, one of which is the rss index file.
        #  As we iterate through we append these to our master index file
        data = File.open(RSS_DIR_PREFIX + "medialibrary_rss_#{filename}.xml").read
        rss += data
    end

    # write out the master index
    rss += "</channel></rss>"
    WriteToFile(RSS_DIR_PREFIX + "medialibrary_rss.xml",rss)

else
    printUsage
end

