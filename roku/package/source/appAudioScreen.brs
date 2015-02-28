function ShowAudioScreen(episodes, selectedEpisode, leftBread, rightBread)

   ' Use a common message port for the audio player and springboard screen
   port = CreateObject("roMessagePort")

   ' Set up the audio player
   audio = CreateObject("roAudioPlayer")
   audio.SetMessagePort(port)
   audio.AddContent({Url: episodes[selectedEpisode].url, StreamFormat: episodes[selectedEpisode].streamFormat})
   audio.SetLoop(0)
   audio.SetNext(0)

   ' Set up the springboard screen
   screen = CreateObject("roSpringboardScreen")
   screen.SetMessagePort(port)
   screen.SetBreadcrumbText(leftBread, rightBread)
   screen.SetStaticRatingEnabled(false)
   screen.AddButton(1, "Play")
   screen.SetContent(episodes[selectedEpisode])
   screen.Show()

   while true
      msg = wait(0, port)
      if type (msg) = "roSpringboardScreenEvent"
         if msg.isScreenClosed()
            exit while
         else if msg.isButtonPressed()
            button = msg.GetIndex ()
            if button = 1                  ' Play Button
               audio.Play()
               screen.ClearButtons()
               screen.AddButton(2, "Pause")
               screen.AddButton(4, "Stop")
            else if button = 2               ' Pause Button
               audio.Pause()
               screen.ClearButtons()
               screen.AddButton(3, "Resume")
               screen.AddButton(4, "Stop")
            else if button = 3               ' Resume Button
               audio.Resume()
               screen.ClearButtons()
               screen.AddButton(2, "Pause")
               screen.AddButton(4, "Stop")
            else if button = 4               ' Stop Button
               audio.Stop()
               screen.ClearButtons()
               screen.AddButton(1, "Play")
            endif
         else if msg.isRemoteKeyPressed()
            if msg.GetIndex() = 4            ' < LEFT
               screen.ClearButtons()
               audio.Stop()
               audio.ClearContent()
               if selectedEpisode = 0
                  selectedEpisode = episodes.Count() - 1
               else
                  selectedEpisode = selectedEpisode - 1
               end if
               audio.AddContent({Url: episodes[selectedEpisode].url, StreamFormat: episodes[selectedEpisode].streamFormat})
               screen.SetContent(episodes[selectedEpisode])
               screen.AddButton(1, "Play")
            else if msg.GetIndex() = 5         ' > RIGHT
               screen.ClearButtons()
               audio.Stop()
               audio.ClearContent()
               if selectedEpisode = episodes.Count() - 1
                  selectedEpisode = 0
               else
                  selectedEpisode = selectedEpisode + 1
               end if
               audio.AddContent({Url: episodes[selectedEpisode].url, StreamFormat: episodes[selectedEpisode].streamFormat})
               screen.SetContent(episodes[selectedEpisode])
               screen.AddButton(1, "Play")
            end if
         end if
      else if type (msg) = "roAudioPlayerEvent"
         ' Do nothing
      end if
   end while

   return selectedEpisode

end function
