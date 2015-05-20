''
''	NWM_MRSS
''	chagedorn@roku.com
''
''	A BrightScript class for parsing standard MRSS files
''	http://video.search.yahoo.com/mrss
''
''	Usage:
''		mrss = NWM_MRSS("http://www.example.com/mrss_feed.xml")	' iniitialize a NWM_MRSS object
''		episodes = mrss.GetEpisodes(10) ' get the first 10 episodes found in the MRSS feed
''		episodes = mrss.GetEpisodes() 	' get all episodes found in the MRSS feed
''

function NWM_MRSS(url,content)
	this = {
		url:	url
    content: content
		
		GetEpisodes:	NWM_MRSS_GetEpisodes
	}
	
	return this
end function

function parseRssXMLItem(item, result)
	util = NWM_Utilities()
  ' result = []
  newItem = {
    streams:			[]
    streamFormat:	"mp4"
    actors:				[]
    categories:		[]
    contentType:	"episode"
  }
  
  ' title
  tmp = item.GetNamedElements("media:title")
  if tmp.Count() > 0
    newItem.title = util.HTMLEntityDecode(ValidStr(tmp[0].GetText()))
    newItem.shortDescriptionLine1 = util.HTMLEntityDecode(ValidStr(tmp[0].GetText()))
  else
    newItem.title = util.HTMLEntityDecode(ValidStr(item.title.GetText()))
    newItem.shortDescriptionLine1 = util.HTMLEntityDecode(ValidStr(item.title.GetText()))
  end if
    
  ' description
  description = util.HTMLEntityDecode(util.HTMLStripTags(ValidStr(item.description.GetText())))
  newItem.description = description
  newItem.synopsis = description

  ' thumbnail
  tmp = item.GetNamedElements("thumbnail")
  if tmp.Count() > 0
    newItem.sdPosterURL = ValidStr(tmp[0]@url)
    newItem.hdPosterURL = ValidStr(tmp[0]@url)
  else if xml.channel.image.url.Count() > 0
    newItem.sdPosterURL = ValidStr(xml.channel.image.url.GetText())
    newItem.hdPosterURL = ValidStr(xml.channel.image.url.GetText())
  end if

  ' subtitles
  tmp = item.GetNamedElements("subtitles")
  if tmp.Count() > 0
    newItem.SubtitleConfig = {
      TrackName: ValidStr(tmp[0]@url)
    }
  end if
  
  ' categories
  if item.GetNamedElements("media:category").Count() > 0
    tmp = item.GetNamedElements("media:category")
    for each category in tmp
      newItem.categories.Push(ValidStr(category.GetText()))
    next
  else if item.category.Count() > 0
    for each category in item.category
      newItem.categories.Push(ValidStr(category.GetText()))
    next
  end if
    
  ' release date
  if item.GetNamedElements("blip:datestamp").Count() > 0
    dt = CreateObject("roDateTime")
    dt.FromISO8601String(ValidStr(item.GetNamedElements("blip:datestamp")[0].GetText()))
    newItem.releaseDate = dt.AsDateStringNoParam()
  else
    newItem.releaseDate = ValidStr(item.pubdate.GetText())
  end if
  newItem.shortDescriptionLine2 = newItem.releaseDate
  
  ' media:content can be a child of <item> or of <media:group>
  contentItems = item.GetNamedElements("content")
  if contentItems.Count() = 0
    tmp = item.GetNamedElements("media:group")
    if tmp.Count() > 0
      contentItems = tmp.GetNamedElements("media:content")
    end if
  end if
  
  ' length
  tmp = item.GetNamedElements("duration")
  if tmp.Count() > 0
    length = StrToI(ValidStr(tmp[0].GetText()))
    if length > 0
      newItem.length = length
    end if
  end if
  
  if contentItems.Count() > 0
    for each content in contentItems
      url = ValidStr(content@url)
      if url <> ""
        newStream = {
          url:		url
          bitrate:	StrToI(ValidStr(content@bitrate))
          quality:  StrToI(ValidStr(content@height))
        }
        
        ' use the content's height attribute to determine HD-ness
        if newStream.quality > 720
          newItem.quality = true
          newItem.HDBranded = true
          newItem.isHD = true
          newItem.fullHD = true
        else if newStream.quality > 480
          newItem.quality = true
          newItem.HDBranded = true
          newItem.isHD = true
        end if

        ' if we detect an mp3 then set the whole item to be mp3 if there are no other vids
        if LCase (Right (url, 4)) = ".mp3" and contentItems.Count() = 1
            newItem.streamFormat = "mp3"
            newItem.url = url
        end if
        newItem.streams.push(newStream)
      end if
    next
    
    length = StrToI(ValidStr(contentItems[0]@duration))
    if newItem.length = invalid and length > 0
      newItem.length = length
    end if

    'PrintAA(newItem)
    result.Push(newItem)
  else if item.enclosure.Count() > 0
    ' we didn't find any media:content tags, try the enclosure tag
    newStream = {
      url:	ValidStr(item.enclosure@url)
    }
    
    newItem.streams.Push(newStream)

    'PrintAA(newItem)
    result.Push(newItem)
  end if
end function

' Build an array of content-meta-data objects suitable for passing to roPosterScreen::SetContentList()
function NWM_MRSS_GetEpisodes(limit = 0)
	result = []
	
    xml = m.content

    ' If the xml data is pulled straight from the Internet
    ' then the node is really the "rss" node
		for each item in xml.channel.item
      parseRssXMLItem(item, result)
		next

    ' If the rss data is a child of a category element
    ' then the xml node is really still the "category" node
		for each item in xml.rss.channel.item
      parseRssXMLItem(item, result)
		next
	
	return result
end function
