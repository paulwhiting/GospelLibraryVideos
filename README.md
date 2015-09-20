## Description

The Gospel Library Videos toolset is designed to enhance access to media content provided by The Church of Jesus Christ of Latter-day Saints.  The objectives are to:
*  simplify media downloads for offline access at home or church when direct Internet access to the Church's servers may be slow or non-existent.
*  provide means to download closed captions so they can be used with videos offline or burned to DVD.
*  provide access to the Church's media content on platforms such as Amazon's Fire TV and Google's Android TV which are not officially supported by the Mormon Channel or Gospel Library apps.
*  provide a feed of videos recently added to the Church's website.
*  audit media metadata for accuracy and ensure videos are available for downloading.


## Accessing Church Media Online

There are currently four different ways to access Church media online (besides going to videos.lds.org):
*  Run the Gospel Library Videos HTML 5 web application directly in your web browser at http://paulwhiting.github.io/GospelLibraryVideos/webapp.  Use your keyboard arrow keys to navigate left and right.  The enter key navigates into folders and plays/pauses videos.  The backspace key quits the player and returns to previous folders.  You may need to zoom in or out to properly fill your browser's screen.
*  For Roku, visit https://owner.roku.com/add/GospelLibraryVideos to add the `Gospel Library Videos` channel to your Roku device.
*  On your Amazon Fire TV device download the `Gospel Library Videos` app from the Amazon App Store.
*  For all other Android TV devices, download the [app from the latest release](https://github.com/paulwhiting/GospelLibraryVideos/releases/download/v0.3.0-beta/Gospel.Library.Videos-0.3.0.apk) and sideload it to your device.  Because the app is sideloaded it probably won't appear on the main launch screen.  To mitigate this issue you can install a [sideload launcher](https://play.google.com/store/apps/details?id=eu.chainfire.tv.sideloadlauncher) to easily start the `Gospel Library Videos` app.

## Downloading Media for Offline Access

A good method for downloading media uses Charles Glancy's [USB Video Manager for Windows](http://glancyfamily.net/USBVideoManager.msi).  It comes with a default library of English videos (and perhaps some Spanish videos) for download, curated by Charles or one of his associates.  The Gospel Library Videos project expands this list of downloadable videos considerably and supports multiple languages.  To take advantage of this larger list change the URL location under the preferences menu item to http://paulwhiting.github.io/GospelLibraryVideos/rss/medialibrary_rss.xml.  Individual videos can be downloaded by right clicking and selecting download or download many by selecting a category and pressing the download button.

You can change the default download directory under preferences, but by default it will be something similar to `C:\Users\(username)\Videos\USB Video Manager\LDS Media`, replacing (username) with your own username.


## Downloading Closed Captions

There are two methods for downloading closed captions from the LDS servers.  After you've downloaded the closed captions you may need to convert them to a more suitable format before using them.

#### Using Firefox's Greasemonkey / Chrome's Tampermonkey

The first and preferred method for downloading subtitles is to use the [Gospel Library Videos Closed Captions Downloader](http://paulwhiting.github.io/GospelLibraryVideos/closed_captions/cc_downloader.user.js) Greasemonkey / Tampermonkey user script.  When you visit [the Church's media library](http://videos.lds.org) with this script enabled in your browser the videos with subtitles should automatically have a subtitles download link as the first item in the download popup box where you normally go to download videos.


#### Using Roku_Export.exe

The second method for downloading subtitles uses the `roku_export.exe` utility distributed in the release package for Gospel Library Videos.  This utility will mass download subtitles for videos you have previously downloaded.  Follow the steps under the Exporting to Roku section below.


#### Coverting the TTML Subtitles

The Church provides subtitles in [Timed Text Markup Language (TTML)](https://en.wikipedia.org/wiki/Timed_Text_Markup_Language).  Many video playing programs, however, expect subtitles in [.srt format](https://en.wikipedia.org/wiki/SubRip#SubRip_text_file_format).  There are a few different ways to convert subtitles and there are several websites that will do this conversion for free.  One that might work well for you is http://www.nikse.dk/SubtitleEdit/Online, but if you find a better website let me know and I'll update this section.


## Accessing Church Media Offline

As the Church already has a nice [guide for showing videos during church](https://ue.ldschurch.org/ldsapphelp/showing-video/printedguides/showingvideohowtoguide.pdf), this section here will be limited to another option made possible by Gospel Library Videos.  If you've ever played a video using your Roku's USB port you'll know how terrible the default channel's user interface is.  It's not pretty.  The Gospel Library Videos channel fixes this by creating a customized video selection screen to show your offline videos in the exact same way you'd show your online videos.  It is easy to use and works well, and it even supports closed captions! 

#### Exporting to Roku (and downloading subtitles)

After you have downloaded your desired videos you can export them to a USB drive for local display on your Roku without needing to stream them over the Internet.

1.  Download `roku_export.exe` from the most recent release package.  This executable is a wrapper for a Ruby script that actually does the work.  The executable extracts the Ruby runtime environment, downloads the metadata as described below, then deletes the Ruby files it extracted.  (NOTE: Not all anti-virus products appreciate this behavior because high disk usage could be indicative of malicious activity.  If you run the executable and nothing happens that might be the reason why.)
2.  In a command prompt, change the directory to where you saved the file and run `roku_export.exe`, pointing it to your USB Video Manager video downloaded directory as follows:
`roku_export "C:\Users\(User)\Videos\USB Video Manager\LDS Media"`

  The program downloads the latest media feeds and searches your video download directory for videos listed in the feeds.  It also:
  *  Downloads missing thumbnails into the (LDS Media) thumbnails subfolder.
  *  Downloads missing subtitles into the (LDS Media) subtitles subfolder.
  *  Creates a `medialibrary_downloaded_(language).xml` file containing your downloaded videos' metadata for each of the supported languages.

3.  Currently, the Gospel Library Videos Roku app only supports one downloaded language file at a time.  Rename your chosen language (i.e., medialibrary_downloaded_English.xml) to medialibrary_downloaded.xml.

4.  Copy your video directory (i.e., `LDS Media`) to a USB device with the following layout, assuming `E:\` is the drive letter for your USB device:
  *  `E:\medialibrary_downloaded.xml`  -  The XML file generated by running `roku_export`
  *  `E:\LDS Media\`  -  Your videos
  *  `E:\LDS Media\thumbnails\`  -  Your thumbnails
  *  `E:\LDS Media\subtitles\`  -  Your subtitles

5.  Repeat these steps any time you download new videos to your USB device.


#### Watching downloaded videos
1.  Start the Gospel Video Libraries channel and plug in your USB device.
2.  Choose the "LDS Media Library on USB" menu item.  It will load the medialibrary_downloaded.xml file from the USB and show you only the videos on your USB instead of from the full online library.
3.  If you properly followed the steps from above to copy your videos to the USB device then you should see a list of your downloaded media.  If instead you see an error message then the Roku couldn't find the files on your USB device;  Verify you copied your videos as well as the metadata file (medialibrary_downloaded.xml) to the appropriate locations on your USB device.
