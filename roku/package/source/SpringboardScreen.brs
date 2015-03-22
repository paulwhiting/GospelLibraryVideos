function ShowSpringboardScreen(episodes, selectedEpisode, leftBread, rightBread)
    if episodes [selectedEpisode].streamFormat = "mp3"
        return ShowAudioScreen(episodes, selectedEpisode, leftBread, rightBread)
    endif
    screen = CreateObject("roSpringboardScreen")
    screen.SetMessagePort(CreateObject("roMessagePort"))
    screen.SetBreadcrumbText(leftBread, rightBread)
    screen.SetStaticRatingEnabled(false)
    screen.AddButton(1, "Play")
    screen.AddButton(3, "Play All")
    screen.Show()
    
    screen.SetContent(episodes[selectedEpisode])
    screen.Show()

    while true
        msg = wait(0, screen.GetMessagePort())
        
        if msg <> invalid
            if msg.isScreenClosed()
                exit while
            else if msg.isButtonPressed()
                if msg.GetIndex() = 3 ' Play all
                  max = episodes.Count()
                  for i = selectedEpisode to max
                    retval = ShowVideoScreen(episodes[i])
                    if retval = -1 then
                      exit for
                    end if
                  next
                else
                  ShowVideoScreen(episodes[selectedEpisode])
                end if
            else if msg.isRemoteKeyPressed()
                if msg.GetIndex() = 4 ' LEFT
                    if selectedEpisode = 0
                        selectedEpisode = episodes.Count() - 1
                    else
                        selectedEpisode = selectedEpisode - 1
                    end if
                    screen.SetContent(episodes[selectedEpisode])
                else if msg.GetIndex() = 5 ' RIGHT
                    if selectedEpisode = episodes.Count() - 1
                        selectedEpisode = 0
                    else
                        selectedEpisode = selectedEpisode + 1
                    end if
                    screen.SetContent(episodes[selectedEpisode])
                end if
            end if
        end if
    end while
    
    return selectedEpisode
end function
