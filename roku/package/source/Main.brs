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
	theme.OverhangPrimaryLogoOffsetHD_Y = "35"

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
    for each category in xml.category
        result.Push(BuildCategory(category))
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
    categories:		  []
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

