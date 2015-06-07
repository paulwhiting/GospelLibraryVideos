/* Model
 *
 * Model for MRSS feed data 
 */

(function (exports) {
    "use strict";

    // the model for the Media Sample Data
    // {Object} appSettings are the user-defined settings from the index page
    function MRSSMediaModel(appSettings) {
         // mixin inheritance, initialize this as an event handler for these events:
         Events.call(this, ['error']);

        this.mediaData       = [];
        this.categoryData    = [];
        this.currData = [];
        this.currentCategory = 0;
        this.currentItem     = 0;
        this.defaultTheme    = "default";
        this.currentlySearchData = false;

         //timeout default to 1 min
         this.TIMEOUT = 60000;

        /**
         * This function loads the initial data needed to start the app and calls the provided callback with the data when it is fully loaded
         * @param {function} the callback function to call with the loaded data
         */
        this.loadInitialData = function (dataLoadedCallback) {
             utils.ajaxWithRetry({
                url: appSettings.dataURL,
                type: 'GET',
                crossDomain: true,
                dataType: 'xml',
                context : this,
                cache : true,
                 timeout: this.TIMEOUT,
                success: function() {
                    var contentData = arguments[0];
                    this.handleXMLData(contentData);
                }.bind(this),
                 error: function(jqXHR, textStatus) {
                    if (jqXHR.status === 0) {
                        this.trigger("error", ErrorTypes.INITIAL_NETWORK_ERROR, errorHandler.genStack());
                        return;
                    }
                    switch (textStatus) {
                        case "timeout" :
                            this.trigger("error", ErrorTypes.INITIAL_FEED_TIMEOUT, errorHandler.genStack());
                            break;
                        case "parsererror" :
                            this.trigger("error", ErrorTypes.INITIAL_PARSING_ERROR, errorHandler.genStack());
                            break;
                        default:
                            this.trigger("error", ErrorTypes.INITIAL_FEED_ERROR, errorHandler.genStack());
                            break;
                    }
                    dataLoadedCallback = null;
                 }.bind(this),
                complete: function() {
                    if (dataLoadedCallback) {
                        dataLoadedCallback();
                    }
                }
            });
        }.bind(this);

        this.setCurrentSubCategory = function(data) {
            this.currSubCategory = data;
        };

        this.getSubCategoryData = function(subCategoryCallback) {
            // clone the original object
            //var returnData = JSON.parse(JSON.stringify(this.currSubCategory));
            var returnData = []; //this.currSubCategory;
            returnData.contents = this.getFullContentsForFolder(this.currSubCategory);
            //returnData.contents = this.filterLiveData(returnData.contents);
            subCategoryCallback(returnData);
        };

        this.getURL = function(url) {
            var contentData;
            return $.ajax({
                url: url,
                type: 'GET',
                crossDomain: true,
                dataType: 'xml',
                context : this,
                cache : true,
                async: false,
                success: function() {
                    contentData = arguments[0];
                }.bind(this),
            }).responseText;
            return contentData;
         };

        this.processChannel = function(channel) {
            var contents = [];
            //console.log("found channel");
            channel.children("item").each(function() {
                //console.log("found item");
                var $xml = $(this);
                var video = {
                    title: $xml.find("title").eq(0).text(),
                    description: $xml.find("description").eq(0).text(),
                    pubDate: "1/1/2015",
                    imgURL: $xml.find("thumbnail").attr("url"),
                    videoURL: $xml.find("content").eq(0).attr("url")
                };
                // if item is mp3 then select the next URL if available (to default to videos instead of audio)
                if ($xml.find("content").length > 1 && video.videoURL.length > 1 && video.videoURL[video.videoURL.length-1] === '3') {
                    video.videoURL = $xml.find("content").eq(1).attr("url");
                }
                if (video.imgURL == undefined || video.imgURL == "") {
                    video.imgURL = "assets/amazon-folder.png";
                }
                //var subtitles = $xml.find("subtitles").eq(0).attr("url");
                //if ( subtitles != undefined ) {
                    //video.tracks = [{src: subtitles}];
                //}
                contents.push(video);
            });

            return contents;
        };

        this.getMoreContent = function(url) {
            var $orig_this = this;
            var cats = [];
            var more = this.getURL(url);
            var $xml = $(more); // magically convert from string to XML object

            //console.log("Got the following data:");
            //console.log($xml);

            // look for subcategories
            $xml.children("category").each(function() {
                var $this = $(this);
                var item = $orig_this.buildContents($this);
                cats.push(item);
            });

            // TODO: this really ought to be cleaner.  this is for categories containing rss
            //$xml.children("rss").each(function() {
                //console.log("found rss");
                //$(this).children("channel").each(function() {
                  //$.merge(cats,$orig_this.processChannel($(this)));
                //});
            //});

            // TODO: this really ought to be cleaner.  this is for AJAXed data
            // that has a root element "rss"
            $xml.children("channel").each(function() {
              //console.log("found rss");
              $.merge(cats,$orig_this.processChannel($(this)));
            });

            return cats;
        };

        this.getFullContentsForFolder = function(folder) {
        var $orig_this = this;
            if (folder.bPopulatedContents == 0) {
                if (folder.url != undefined && folder.url != "") {
                    console.log(folder.url);
                    folder.contents = this.getMoreContent(folder.url);
                    //if (folder.contents != []) {
                        folder.bPopulatedContents = 1;
                    //}
                } else {
                    // look for subcategories
                    folder.xmlObject.children("category").each(function() {
                        var $this = $(this);
                        var item = $orig_this.buildContents($this);
                        folder.contents.push(item);
                    });
                    folder.bPopulatedContents = 1;
                }
            }
            return folder.contents;
         };



        /** my function to do awesome things */
        this.buildContents = function (xmlData) {
            var $orig_this = this;
            var $this = $(this);
            var $xml = $(xmlData);
            var item = {
                title: $xml.attr("title"),
                url: $xml.attr("url"),
                description: $xml.attr("subtitle"),
                pubDate: "1/1/2015",
                imgURL: $xml.attr("img"),
                thumbURL: $xml.attr("img"),
                contents: [],
                type: "subcategory",
                bPopulatedContents: 0,
                xmlObject: $xml
            };

            if (item.imgURL == undefined) {
                item.imgURL = "assets/amazon-folder.png";
            }

            item.thumbURL = item.imgURL;

            $xml.children("rss").each(function() {
            $(this).children("channel").each(function() {
            $(this).children("item").each(function() {
                //console.log("found item");
                var $xml = $(this);
                var video = {
                    title: $xml.find("title").eq(0).text(),
                    description: $xml.find("description").eq(0).text(),
                    pubDate: "1/1/2015",
                    imgURL: $xml.find("thumbnail").attr("url"),
                    videoURL: $xml.find("content").eq(0).attr("url")
                };
                // if item is mp3 then select the next URL if available (to default to videos instead of audio)
                if ($xml.find("content").length > 1 && video.videoURL.length > 1 && video.videoURL[video.videoURL.length-1] === '3') {
                    video.videoURL = $xml.find("content").eq(1).attr("url");
                }
                if (video.imgURL == undefined || video.imgURL == "") {
                    video.imgURL = "assets/amazon-folder.png";
                }
                //var subtitles = $xml.find("subtitles").eq(0).attr("url");
                //if ( subtitles != undefined ) {
                    //video.tracks = [{src: subtitles}];
                //}
                //if ($xml.find("live") != undefined) {
                  //video.type = "video-live";
                  //video.isLiveNow = true;
                //}
                item.contents.push(video);
            });
            });
            });


            return item;

        }.bind(this);


       /**
        * Handles mrss feed requests that return XML data 
        * @param {Object} xmlData data returned from request
        */
        this.handleXMLData = function (xmlData) {
            var $orig_this = this;
            var $xml = $(xmlData);
            var cats = [];
            var itemsInCategory = []; 

            $xml.find("categories > category").each(function() {
                var $this = $(this);

                var item = $orig_this.buildContents($this);
                //if ( c.categories.length > 0 ) {
                    //cats.push(c);
                    var category = "Main Menu"; //item.title; //"all";
                    itemsInCategory[category] = itemsInCategory[category] || [];
                    itemsInCategory[category].push(item);
                    cats.push(category);
                //}
            });

            $.unique(cats); // purge duplicates.
            this.categories = cats;
            this.categoryData = cats;
            this.mediaData = itemsInCategory;
            this.setCurrentCategory(0);
        }.bind(this);

       /***************************
        *
        * Utilility Methods
        *
        ***************************/
       /**
        * Sort the data array alphabetically
        * This method is just a simple sorting example - but the
        * data can be sorted in any way that is optimal for your application
        */
        this.sortAlphabetically = function (arr) {
            arr.sort();
        };

       /***************************
        *
        * Media Data Methods
        *
        ***************************/
        /**
         * For single views just send the whole media object
         */
         this.getAllMedia = function () {
             return mediaData;
         };

       /***************************
        *
        * Category Methods
        *
        ***************************/
        /**
         * Hang onto the index of the currently selected category
         * @param {Number} index the index into the categories array
         */
         this.setCurrentCategory = function (index) {
             this.currentCategory = index;
         };

       /***************************
        *
        * Content Item Methods
        *
        ***************************/
        /**
         * Return the category items for the left-nav view
         */
         this.getCategoryItems = function () {
             return this.categoryData;
         };

        /** 
         * Get and return data for a selected category
         * @param {Function} categoryCallback method to call with returned requested data
         */  
         this.getCategoryData = function (categoryCallback) {
             this.currData = this.mediaData[this.categoryData[this.currentCategory]];
             categoryCallback(this.currData);
         };   

        /**
         * Get and return data for a search term
         * @param {string} searchTerm to search for
         * @param {Function} searchCallback method to call with returned requested data
         */
         this.getDataFromSearch = function (searchTerm, searchCallback) {
            this.currData = [];
            for (var i = 0; i < this.mediaData.length; i++) {
                if (this.mediaData[i].title.toLowerCase().indexOf(searchTerm) >= 0 || this.mediaData[i].description.toLowerCase().indexOf(searchTerm) >= 0) {
                    this.currData.push(this.mediaData[i]);
                }
            }
            searchCallback(this.currData);
         };

       /**
        * Store the refrerence to the currently selected content item
        * @param {Number} index the index of the selected item
        */
        this.setCurrentItem = function (index) {
            this.currentItem = index;
            this.currentItemData = this.currData[index];
        };

       /**
        * Retrieve the reference to the currently selected content item
        */
        this.getCurrentItemData = function () {
            return this.currentItemData;
        };
    }

    exports.MRSSMediaModel = MRSSMediaModel;
})(window);

