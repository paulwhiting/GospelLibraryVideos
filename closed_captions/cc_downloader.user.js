// ==UserScript==
// @name         LDS Closed Caption Downloader
// @namespace    http://github.com/paulwhiting/GospelLibraryVideos/
// @version      0.1
// @description  Inserts a download link for TTML closed captions in the LDS media library.
// @author       Paul Whiting
// @match        https://www.lds.org/media-library/video/*
// @match        http://www.lds.org/media-library/video/*
// @require      http://ajax.googleapis.com/ajax/libs/jquery/2.1.1/jquery.min.js
// @require      https://gist.github.com/raw/2625891/waitForKeyElements.js
// not require      http://courses.ischool.berkeley.edu/i290-4/f09/resources/gm_jq_xhr.js
// @grant        GM_log
// @grant        GM_addStyle
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_listValues
// @grant        GM_xmlhttpRequest
// ==/UserScript==


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


var g_last_updated = GM_getValue("Last-Modified","");
var g_url = "http://paulwhiting.github.io/GospelLibraryVideos/closed_captions/subtitles.json";
var g_jsondata = GM_getValue("json","");
var g_json = '';

if (g_jsondata !== "") {
    g_json = $.parseJSON(g_jsondata);
}

// returns true if DB needs to be updated and sets g_last_updated to the file date
function checkGMDatabase() {
    GM_xmlhttpRequest({
        method: "HEAD",
        url: g_url,
        ignorecache: true,
        onload: function(response) {
            var last = parseResponseHeaders(response.responseHeaders)['Last-Modified'];
//            alert(g_last_updated);
//            alert(last);
            if (g_last_updated === '' || g_last_updated != last) {
                alert('downloading newer db version. Press okay then wait for the next prompt...');
                g_last_updated = last;
                updateGMDatabase();
            } else {
//                alert('db up to date');
                waitForKeyElements("#download-popup", addCCLink);
            }
        }
    });
}

function subtitle_info(data) {
    var count = 0;
    $.each( data, function( key, val ) {
            GM_setValue(key, val);
            GM_log("key: " + key + " and val: " + val);
            count = count + 1;
        });
    GM_log(count);
    GM_setValue("Last-Modified", g_last_updated);
    alert('finished updating closed captions database.');    
}

function updateGMDatabase() {
    var url = g_url;
    var success = function(data) {
        alert('in successsss!!!!!!');
        var count = 0;
        $.each( data, function( key, val ) {
            GM_setValue(key, val);
            count = count + 1;
        });
        GM_setValue("Last-Modified", g_last_updated);
        alert('finished updating closed captions database.');
    };
    
    var error = function(data) {
        alert("no");
        GM_log('something bad happened');
    };
    
//    alert("before");
    GM_xmlhttpRequest({
        method: "GET",
//        jsonpCallback: "subtitle_info",
        cache: false,
        url: url,
        success: success,
        //crossDomain: true
//        fail: function(data) {alert("error");},
//        done: function(data) {alert("completed");},
//        always: function(data) {alert("always2");},
        onload: function(response) {
            var json = $.parseJSON(response.responseText);
            //alert(json);
            GM_setValue("json",response.responseText);
            GM_setValue("Last-Modified",g_last_updated);
            alert('finished updating closed captions database.');    
            waitForKeyElements("#download-popup", addCCLink);
        }
    });
//    alert("after");
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
}

checkGMDatabase();

