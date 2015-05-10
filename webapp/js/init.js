(function(exports) {
    'use strict';
    
    //initialize the app
    var settings = {
        Model: MRSSMediaModel,
        PlayerView: PlayerView,
        PlaylistView: PlaylistPlayerView,
        dataURL: "./assets/main.xml",
        showSearch: false,
        displayButtons: false
    };

    exports.app = new App(settings);
}(window));
