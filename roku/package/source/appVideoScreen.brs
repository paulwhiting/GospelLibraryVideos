'**********************************************************
'**  Video Player Example Application - Video Playback 
'**  November 2009
'**  Copyright (c) 2009 Roku Inc. All Rights Reserved.
'**********************************************************

'***********************************************************
'** Create and show the video screen.  The video screen is
'** a special full screen video playback component.  It 
'** handles most of the keypresses automatically and our
'** job is primarily to make sure it has the correct data 
'** at startup. We will receive event back on progress and
'** error conditions so it's important to monitor these to
'** understand what's going on, especially in the case of errors
'***********************************************************  
Function showVideoScreen(episode As Object, stream_url = "")
  if type(episode) <> "roAssociativeArray" then
    print "invalid data passed to showVideoScreen"
    return -1
  end if

  port = CreateObject("roMessagePort")
  screen = CreateObject("roVideoScreen")
  screen.SetMessagePort(port)
  screen.Show()

  vid_to_play = episode

  if stream_url <> "" then
    print "Choosing to play url "; stream_url
    format = episode.StreamFormat
    
    if LCase (Right (stream_url, 4)) = ".mp3"
      format = "mp3"
    end if
      
    vid_to_play = {
      Stream: { url: stream_url }
      StreamFormat: episode.StreamFormat
      Title: episode.title
      SubtitleConfig: episode.SubtitleConfig
    }
  end if

  screen.SetContent(vid_to_play)
  screen.Show()

  'Uncomment his line to dump the contents of the episode to be played
  'PrintAA(episode)

  while true
    msg = wait(0, port)

    if type(msg) = "roVideoScreenEvent" then
      print "showHomeScreen | msg = "; msg.getMessage() " | index = "; msg.GetIndex()
      if msg.isFullResult()
        ' video completed on its own
        return -2
      elseif msg.isScreenClosed()
        print "Screen closed"
        return -1
      elseif msg.isRequestFailed()
        print "Video request failure: "; msg.GetIndex(); " " msg.GetData() 
      elseif msg.isStatusMessage()
        print "Video status: "; msg.GetIndex(); " " msg.GetData() 
      elseif msg.isButtonPressed()
        print "Button pressed: "; msg.GetIndex(); " " msg.GetData()
      else
        print "Unexpected event type: "; msg.GetType()
      end if
    else
      print "Unexpected message class: "; type(msg)
    end if
  end while
End Function
