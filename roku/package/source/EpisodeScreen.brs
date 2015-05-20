sub ShowEpisodeScreen(show, leftBread, rightBread)

	screen = CreateObject("roPosterScreen")
	screen.SetMessagePort(CreateObject("roMessagePort"))
  screen.SetListStyle("flat-episodic-16x9")
  'screen.SetListStyle("flat-category")
  screen.SetBreadcrumbText(leftBread, rightBread)
	screen.Show()

  Dbg("episode url: ", show.url)
  Dbg("episode rss: ", show.content)

  mrss = NWM_MRSS(show.url,show.content)
  content = mrss.GetEpisodes()
  if content.Count() = 0
    ' TODO: show an error dialog
    return
  end if

	selectedEpisode = 0
	screen.SetContentList(content)
	screen.Show()

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
          if content[selectedEpisode].streamFormat = "mp3"
            ShowAudioScreen(content, selectedEpisode, leftBread, "")
          else
            ShowVideoScreen(content[selectedEpisode])
          end if
				end if
			end if
		end if
	end while
end sub
