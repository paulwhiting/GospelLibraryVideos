sub Main()
	categories = LoadConfig()
  ShowPosterScreen(categories, "Gospel Library", "Videos", 1, 0)
end sub

function LoadConfig()
	result = []

	app = CreateObject("roAppManager")
	theme = CreateObject("roAssociativeArray")
	theme.OverhangSliceSD = "pkg:/images/overhang_slice_sd.png"
	theme.OverhangSliceHD = "pkg:/images/overhang_slice_hd.png"
	theme.OverhanglogoHD = "pkg:/images/overhang_logo_hd.png"
	theme.OverhanglogoSD = "pkg:/images/overhang_logo_sd.png"

	theme.OverhangPrimaryLogoOffsetHD_X = "100"
	theme.OverhangPrimaryLogoOffsetHD_Y = "60"

	theme.OverhangPrimaryLogoOffsetSD_X = "60"
	theme.OverhangPrimaryLogoOffsetSD_Y = "40"

	raw = ReadASCIIFile("pkg:/config.opml")
	opml = CreateObject("roXMLElement")
	if opml.Parse(raw)
		theme.backgroundColor = ValidStr(opml.categories@backgroundColor)
		theme.breadcrumbTextLeft = ValidStr(opml.categories@leftBreadcrumbColor)
		theme.breadcrumbDelimiter = ValidStr(opml.categories@rightBreadcrumbColor)
		theme.breadcrumbTextRight = ValidStr(opml.categories@rightBreadcrumbColor)
		
		theme.posterScreenLine1Text = ValidStr(opml.categories@posterScreenTitleColor)
		theme.posterScreenLine2Text = ValidStr(opml.categories@posterScreenSubtitleColor)
		theme.episodeSynopsisText = ValidStr(opml.categories@posterScreenSynopsisColor)
		
		theme.springboardTitleText = ValidStr(opml.categories@springboardScreenTitleColor)
		theme.springboardSynopsisColor = ValidStr(opml.categories@springboardScreenSynopsisColor)
		theme.springboardRuntimeColor = ValidStr(opml.categories@springboardScreenDateColor)
		theme.springboardDirectorColor = ValidStr(opml.categories@springboardScreenDirectorColor)
		theme.springboardDirectorLabelColor = ValidStr(opml.categories@springboardScreenDirectorColor)
		theme.springboardActorColor = ValidStr(opml.categories@springboardScreenActorColor)
		theme.springboardGenreColor = ValidStr(opml.categories@springboardScreenCategoryColor)

        ParseCategoriesFromXML(opml.categories,result)
	end if

	app.SetTheme(theme)
	
	return result
end function


function ParseCategoriesFromXML(xml,result)
    Dbg("First Here we are!! ")
    ' If we are doing regular original XML
    for each category in xml.category
        result.Push(BuildCategory(category))
    next

    ' for parsing glancy root XML <rss>
    Dbg("Second Here we are!! ")
    ? xml
    Dbg("I wish I were better at this is: ", xml)
    for each item in xml.channel.item
        result.Push(BuildCategoryFromGlancyRSS(item))
    next

    ' for parsing glancy root XML <library>
    Dbg("third Here we are!! ")
    for each category in xml.categories.category
        result.Push(BuildCategoryFromGlancyLibrary(category,xml))
    next
end function


function BuildCategory(category)
	result = {
		title:	ValidStr(category@title)
		shortDescriptionLine1:	ValidStr(category@title)
		shortDescriptionLine2:	ValidStr(category@subtitle)
		sdPosterURL:						ValidStr(category@img)
		hdPosterURL:						ValidStr(category@img)
		'sdBackgroundImageUrl:						ValidStr(category@img)
		'hdBackgroundImageUrl:						ValidStr(category@img)
		url:										ValidStr(category@url)
        bPopulatedCategories:       0
        bShowAsList:                ValidStr(category@showaslist).toInt()
        bShowAsPortrait:            ValidStr(category@showasportrait).toInt()
		categories:							[]
        content:        category
        videos:         []
	}
	
	if category.category.Count() > 0
		for each subCategory in category.category
			result.categories.Push(BuildCategory(subCategory))
		next
	end if
	
	return result
end function

function BuildCategoryFromGlancyRSS(item)
	result = {
		title:	ValidStr(item.title.getText())
		shortDescriptionLine1:	ValidStr(item.title.getText())
		shortDescriptionLine2:	ValidStr(item.description.getText())
		'sdPosterURL:						ValidStr(category@img)
		'hdPosterURL:						ValidStr(category@img)
		'sdBackgroundImageUrl:						ValidStr(category@img)
		'hdBackgroundImageUrl:						ValidStr(category@img)
		url:										ValidStr(item.link.getText())
        bPopulatedCategories:       0
        bShowAsList:                1
        bShowAsPortrait:            0
		categories:					[]
        content:        {}
        videos:         []
	}
	
	return result
end function

function BuildCategoryFromGlancyLibrary(category,xml)
	result = {
		title:	ValidStr(category@name)
		shortDescriptionLine1:	ValidStr(category@name)
		shortDescriptionLine2:	ValidStr("")
		sdPosterURL:						ValidStr(category@thumbnail)
		hdPosterURL:						ValidStr(category@thumbnail)
		'sdBackgroundImageUrl:						ValidStr(category@img)
		'hdBackgroundImageUrl:						ValidStr(category@img)
		url:										ValidStr(category@url)
        bPopulatedCategories:       0
        bShowAsList:                0
        bShowAsPortrait:            0
		categories:							[]
        content:        category
        videos:        []
	}
	
	if category.category.Count() > 0
		for each subCategory in category.category
			result.categories.Push(BuildCategoryFromGlancyLibrary(subCategory,xml))
		next
	end if

	if category.videoref.Count() > 0
		for each videoref in category.videoref
            id = videoref@ref
			result.videos.Push(ParseVideoRef(xml,id))
		next
	end if
	
	return result
end function

function ParseVideoRef(xml,ref_id)
    'dbg("boo")
    'dbg("attempting to find video in list...", videolist.count())
    '? videolist
    for each video in xml.videos.video
        'dbg("video@id: ", video@id)
        'dbg("ref_id: ", ref_id)
        if video@id = ref_id
            'Dbg("found video: ", video@name)
            result = {
                title: ValidStr(video@name)
                shortDescriptionLine1:	ValidStr(video@name)
                shortDescriptionLine2:	ValidStr("")
                sdPosterURL:			ValidStr(video@thumbnail)
                hdPosterURL:			ValidStr(video@thumbnail)
                streams: []
                streamFormat: "mp4"
				actors:				[]
				categories:		[]
				contentType:	"episode"
            }
            newstream = {
                url:					ValidStr(video@url)
            }
            result.streams.Push(newstream)

            return result
        end if
    next

    return {}
end function
