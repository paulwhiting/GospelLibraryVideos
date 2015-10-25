// ==UserScript==
// @name         LDS Closed Caption Downloader
// @namespace    http://github.com/paulwhiting/GospelLibraryVideos/
// @version      0.2
// @description  Inserts a download link for TTML closed captions in the LDS media library.
// @author       Paul Whiting
// @match        https://www.lds.org/media-library/video/*
// @match        http://www.lds.org/media-library/video/*
// @require      http://ajax.googleapis.com/ajax/libs/jquery/2.1.1/jquery.min.js
// @require      https://gist.github.com/raw/2625891/waitForKeyElements.js
// @grant        GM_log
// @grant        GM_addStyle
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_listValues
// @grant        GM_xmlhttpRequest
// ==/UserScript==

var g_last_updated = GM_getValue("Last-Modified","");
var g_last_checked = getLastChecked();
var g_url = "http://paulwhiting.github.io/GospelLibraryVideos/closed_captions/subtitles.json";
var g_jsondata = GM_getValue("json","");
var g_json = '';
var g_checkthreshold = 200 * 60 * 1000; // 200 minutes (where 1 second = 1000)


function parseResponseHeaders(headerStr) {
  var headers = {};
  if (!headerStr) {
    return headers;
  }
  var headerPairs = headerStr.split('\u000d\u000a');
  for (var i = 0; i < headerPairs.length; i++) {
    var headerPair = headerPairs[i];
    var index = headerPair.indexOf('\u003a\u0020');
    if (index > 0) {
      var key = headerPair.substring(0, index);
      var val = headerPair.substring(index + 2);
      headers[key] = val;
    }
  }
  return headers;
}

// http://stackoverflow.com/questions/15043910/greasemonkey-script-fails-passing-date-time-to-gm-setvalue
function setLastChecked() {
    var time = Math.floor((new Date().getTime() / 1000) - 1356998400);
    GM_setValue("Last-Checked", time);
}
function getLastChecked() {
    var lastchecked = new Date((GM_getValue("Last-Checked", 0)+1356998400)*1000);
    return lastchecked;
}

// returns true if DB needs to be updated and sets g_last_updated to the file date
function checkGMDatabase() {
    GM_xmlhttpRequest({
        method: "HEAD",
        url: g_url,
        ignorecache: true,
        onload: function(response) {
            var last = parseResponseHeaders(response.responseHeaders)['Last-Modified'];
            if (g_last_updated === '' || g_last_updated != last) {
                //alert('downloading newer db version. Press okay then wait for the next prompt...');
                g_last_updated = last;
                updateGMDatabase();
            } else {
//                alert('db up to date');
                setLastChecked();
                waitForKeyElements("#download-popup", addCCLink);
            }
        }
    });
}

function updateGMDatabase() {    
    GM_xmlhttpRequest({
        method: "GET",
        cache: false,
        ignorecache: true,
        url: g_url,
        onload: function(response) {
            var json = $.parseJSON(response.responseText);
            GM_setValue("json",response.responseText);
            GM_setValue("Last-Modified",g_last_updated);
            setLastChecked();
            //alert('finished updating closed captions database.');    
            waitForKeyElements("#download-popup", addCCLink);
        }
    });
}


function addCCLink( jNode ) {
    downloads = $( "#download-popup ul li a" );
    for (var i = 0; i < downloads.length; i+=1) {
        link = downloads[i].href.replace("?download=true","");
        GM_log("checking " + link);
        if (g_json.hasOwnProperty(link)) {
            //alert('found!');
            var cc_node = '<li><a href="' + g_json[link] + '">Closed Captions (TTML)</a><span></span></li>';
            $('#download-popup > ul').prepend(cc_node);
            return;
        }
    }
    var notfound = '<li><a href="' + g_json[link] + '">Closed Captions (TTML)</a><span></span></li>';
    $('#download-popup > ul').prepend(cc_node);
}


// if we don't have saved data or if it's been long enough check for updates
var curdate = new Date();

if (g_jsondata === "" || curdate - g_last_checked > g_checkthreshold) {
    //alert("checking");
    checkGMDatabase();
} else {
    //alert("not checking");
    g_json = $.parseJSON(g_jsondata);
    waitForKeyElements("#download-popup", addCCLink);
}


