Function ShowMessageDialog_USBError(file) As Void
    port = CreateObject("roMessagePort")
    dialog = CreateObject("roMessageDialog")
    dialog.SetMessagePort(port)
    dialog.SetTitle("USB Error")
    dialog.SetText("The file at " + file + " was not found.  To play videos from USB follow the instructions at github.com/paulwhiting/GospelLibraryVideos/releases")
 
'    count = 1
'    for each stream in episode.streams
    dialog.AddButton(1, "Okay")
'      count = count + 1
'    next
    dialog.EnableBackButton(true)
    dialog.Show()
    While True
        dlgMsg = wait(0, dialog.GetMessagePort())
        If type(dlgMsg) = "roMessageDialogEvent"
            if dlgMsg.isButtonPressed()
'                index = dlgMsg.GetIndex()
'                if index >= 1 and index < count
'                    dialog.close()
'                    retval = ShowVideoScreen(episode,episode.streams[index-1].url)
'                    exit while
'                end if
'            else if dlgMsg.isScreenClosed()
                exit while
            end if
        end if
    end while
End Function

Function doCerts(screen)
  ' use certs to allow for https thumbnails
  screen.SetCertificatesFile("common:/certs/ca-bundle.crt")
  'screen.SetCertificatesDepth(10)
  screen.InitClientCertificates()
End Function

sub ShowPosterScreen(contentList, breadLeft, breadRight, bAsListScreen, bAsPortrait)
    Dbg("bAsListScreen: ", bAsListScreen)
    
    if bAsListScreen = 1
        ' for roListScreen
        screen = CreateObject("roListScreen")
        screen.SetMessagePort(CreateObject("roMessagePort"))
        doCerts(screen)
        screen.SetContent(contentList)
    else
        if false
            screen = CreateObject("roPosterScreen")
            screen.SetMessagePort(CreateObject("roMessagePort"))
            doCerts(screen)
            if bAsPortrait = 1
                screen.SetListStyle("arced-portrait")
            else
                screen.SetListStyle("flat-category")
            end if
            screen.SetContentList(contentList)
        end if
        if true
            screen = CreateObject("roGridScreen")
            screen.SetDisplayMode("scale-to-fit")
            screen.SetMessagePort(CreateObject("roMessagePort"))
            doCerts(screen)

            count = contentList.count()
            ' 4 or 5 per row...
            maxcol = 4
            numrows = int(count / maxcol)
            if count MOD maxcol > 0
              numrows = numrows + 1
            end if
            screen.SetupLists(numrows) ' count of rows
            labels = []

            row = 0
            col = 1
            gridarr = []
            for each i in contentList
                gridarr.push(i)
                if col = maxcol
                    labels.push("")     ' ("row " + str(row))
                    screen.setContentList(row,gridarr)
                    gridarr = []
                    row = row + 1
                    col = 0
                end if
                col = col + 1
            next
            if row < numrows
                labels.push("")     ' ("row " + str(row))
                screen.setContentList(row,gridarr)
            end if
            screen.setListNames(labels)
        end if
    end if    ' as list screen

    ' now both
    screen.SetBreadcrumbText(breadLeft, breadRight)
    screen.Show()
	
    while true
        msg = wait(0, screen.GetMessagePort())
      
        if msg <> invalid
            if msg.isScreenClosed()
                exit while
            else if msg.isListItemFocused()
            else if msg.isListItemSelected()
                if Type(screen) = "roGridScreen"
                    ' print "Selected msg: ";msg.GetMessage();"row: ";msg.GetIndex();
                    ' print " col: ";msg.GetData()
                    selectedItem = contentList[(msg.GetIndex() * maxcol) + msg.GetData()]
                else
                    selectedItem = contentList[msg.Getindex()]
                end if
                Dbg("url: ", selectedItem.url)

                if selectedItem.url <> "" and selectedItem.bPopulatedCategories = 0
                    Dbg("url: ", selectedItem.url)
                    protocol = selectedItem.url.Left(3)
                    if protocol = "pkg" or protocol = "ext"
                        ' use file from package
                        rsp = ReadASCIIFile(selectedItem.url)
                        if rsp = "" and protocol = "ext"
                            ' there was an error reading from the USB.  Print error message.
                            ShowMessageDialog_USBError(selectedItem.url)
                            goto continue
                        end if
                    else
                        http = NewHttp(selectedItem.url)
                        print "really it is Doing category stuff now"
                        rsp = http.GetToStringWithRetry()
                    end if  ' protocol

                    xml=CreateObject("roXMLElement")
                    if not xml.Parse(rsp) then
                        print "Can't parse feed"
                        goto continue
                    endif

                    ParseCategoriesFromXML(xml,SelectedItem.categories)
                    if selectedItem.categories.Count() = 0
                        ' if we fail to parse a category from the XML then assume it's episode info
                        selectedItem.content = xml
                    end if
                    selectedItem.bPopulatedCategories = 1
                end if  ' selecteditem.url and not populated

                if selectedItem.categories.Count() > 0
                    layout = bAsPortrait
                    if layout = 0
                        layout = selectedItem.bShowAsPortrait
                    end if
                    ShowPosterScreen(selectedItem.categories, selectedItem.shortDescriptionLine1, "", selectedItem.bShowAsList, layout)
                else
                    ShowEpisodeScreen(selectedItem, selectedItem.shortDescriptionLine1, "")
                end if
            end if
        end if  ' msg is valid
        continue:
    end while  ' true
end sub
