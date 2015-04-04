Function ShowMessageDialog_ChooseQuality(episode) As Void
    port = CreateObject("roMessagePort")
    dialog = CreateObject("roMessageDialog")
    dialog.SetMessagePort(port)
    dialog.SetTitle("Choose Quality")
    dialog.SetText("Choose the video quality to play")
 
    count = 1
    for each stream in episode.streams
      dialog.AddButton(count, StrI(stream.quality))
      count = count + 1
    next
    dialog.EnableBackButton(true)
    dialog.Show()
    While True
        dlgMsg = wait(0, dialog.GetMessagePort())
        If type(dlgMsg) = "roMessageDialogEvent"
            if dlgMsg.isButtonPressed()
                index = dlgMsg.GetIndex()
                if index >= 1 and index < count
                    dialog.close()
                    retval = ShowVideoScreen(episode,episode.streams[index-1].url)
                    exit while
                end if
            else if dlgMsg.isScreenClosed()
                exit while
            end if
        end if
    end while
End Function


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
    screen.AddButton(4, "Choose Quality")
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
                else if msg.GetIndex() = 4 ' Choose Quality
                  ShowMessageDialog_ChooseQuality(episodes[selectedEpisode])
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
