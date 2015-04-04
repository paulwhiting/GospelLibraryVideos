sub ShowPosterScreen(contentList, breadLeft, breadRight, bAsListScreen, bAsPortrait)
    Dbg("bAsListScreen: ", bAsListScreen)
    
    if bAsListScreen = 1
        ' for roListScreen
        screen = CreateObject("roListScreen")
        ' use certs to allow for https thumbnails
        screen.SetCertificatesFile("common:/certs/ca-bundle.crt")
        'screen.SetCertificatesDepth(10)
        screen.InitClientCertificates()
        screen.SetMessagePort(CreateObject("roMessagePort"))
        screen.SetContent(contentList)
    else
        screen = CreateObject("roPosterScreen")
        ' use certs to allow for https thumbnails
        screen.SetCertificatesFile("common:/certs/ca-bundle.crt")
        'screen.SetCertificatesDepth(10)
        screen.InitClientCertificates()
        if bAsPortrait = 1
            screen.SetListStyle("arced-portrait")
        else
            screen.SetListStyle("flat-category")
        end if
        screen.SetMessagePort(CreateObject("roMessagePort"))
        screen.Show()
        screen.SetContentList(contentList)
    end if

    ' now both
    screen.SetBreadcrumbText(breadLeft, breadRight)
	screen.Show()
	
	while true
		msg = wait(0, screen.GetMessagePort())
		
		if msg <> invalid
			if msg.isScreenClosed()
				exit while
			else if msg.isListItemSelected()
				selectedItem = contentList[msg.Getindex()]
                Dbg("url: ", selectedItem.url)

                if selectedItem.url <> "" and selectedItem.bPopulatedCategories = 0
                    Dbg("url: ", selectedItem.url)
                    protocol = selectedItem.url.Left(3)
                    if protocol = "pkg" or protocol = "ext"
                        ' use file from package
                        rsp = ReadASCIIFile(selectedItem.url)
                    else
                        http = NewHttp(selectedItem.url)
                        print "really it is Doing category stuff now"
                        rsp = http.GetToStringWithRetry()
                    end if

                    xml=CreateObject("roXMLElement")
                    if not xml.Parse(rsp) then
                        print "Can't parse feed"
                        return
                    endif

                    print "category check"
                    ParseCategoriesFromXML(xml,SelectedItem.categories)
                    print "done here"
                    selectedItem.bPopulatedCategories = 1
                end if

                print "before if"

				if selectedItem.categories.Count() > 0
                    print "category count > 0"
                    layout = bAsPortrait
                    if layout = 0
                        layout = selectedItem.bShowAsPortrait
                    end if
					ShowPosterScreen(selectedItem.categories, selectedItem.shortDescriptionLine1, "", selectedItem.bShowAsList, layout)
				else
                    print "category count is 0"
					ShowEpisodeScreen(selectedItem, selectedItem.shortDescriptionLine1, "")
				end if
			end if
		end if
	end while
end sub
