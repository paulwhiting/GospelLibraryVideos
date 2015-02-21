sub ShowEpisodeScreen(show, leftBread, rightBread)

    print "episode screen begin"

	screen = CreateObject("roPosterScreen")
	screen.SetMessagePort(CreateObject("roMessagePort"))
    screen.SetListStyle("flat-episodic")
    screen.SetBreadcrumbText(leftBread, rightBread)
	screen.Show()

    Dbg("episode url: ", show.url)
    Dbg("episode rss: ", show.content)
	
    Dbg("Glancy video count: ", show.videos.count())
    if show.videos.count() > 0
        print "Using glancy vids"
        content = show.videos
    else
        print "Using regular vids"
        mrss = NWM_MRSS(show.url,show.content)
        content = mrss.GetEpisodes()
        if content.Count() = 0
            return
        end if
    end if

	selectedEpisode = 0
	screen.SetContentList(content)
	screen.Show()

    print "episode list while true"
	while true
		msg = wait(0, screen.GetMessagePort())
		
		if msg <> invalid
			if msg.isScreenClosed()
				exit while
			else if msg.isListItemFocused()
				selectedEpisode = msg.GetIndex()
			else if msg.isListItemSelected()
				selectedEpisode = ShowSpringboardScreen(content, selectedEpisode, leftBread, "")
				screen.SetFocusedListItem(selectedEpisode)
				'screen.Show()
			else if msg.isRemoteKeyPressed()
        if msg.GetIndex() = 13
					ShowVideoScreen(content[selectedEpisode])
				end if
			end if
		end if
	end while
end sub
