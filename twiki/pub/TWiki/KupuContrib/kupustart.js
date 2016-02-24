/*
   Copyright (C) 2005 ILOG http://www.ilog.fr
   and TWiki Contributors. All Rights Reserved. TWiki Contributors
   are listed in the AUTHORS file in the root of this distribution.
   NOTE: Please extend that file, not this notice.

   Portions Copyright (c) 2003-2004 Kupu Contributors. All rights reserved.

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.
  
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  
   As per the GPL, removal of this notice is prohibited.
*/

/*
 * TWiki-specific customisation of kupustart.js
 */

function startKupu() {
    // first let's load the message catalog
    // if there's no global 'i18n_message_catalog' variable available, don't
    // try to load any translations
    if (window.i18n_message_catalog) {
        var request = new XMLHttpRequest();
        // sync request, scary...
        request.open('GET', 'kupu-pox.cgi', false);
        request.send('');
        if (request.status != '200') {
            alert('Error loading translation (status ' + status +
                    '), falling back to english');
        } else {
            // load successful, continue
            var dom = request.responseXML;
            window.i18n_message_catalog.initialize(dom);
        };
    };

    // initialize the editor, initKupu groks 1 arg, a reference to the iframe
    var frame = getFromSelector('kupu-editor'); 
    var kupu = initKupu(frame);

    kupu.registerContentChanger(getFromSelector('kupu-editor-textarea'));

    var navigatingAway = function () {
      TWikiVetoIfChanged(kupu, true);
    }

    if (kupu.getBrowserName() == 'IE') {
        // IE supports onbeforeunload, so let's use that
        addEventHandler(window, 'beforeunload', navigatingAway);
    } else {
        // some versions of Mozilla support onbeforeunload (starting with 1.7)
        // so let's try to register and if it fails fall back on onunload
        var re = /rv:([0-9\.]+)/
        var match = re.exec(navigator.userAgent)
        if (match[1] && parseFloat(match[1]) > 1.6) {
            addEventHandler(window, 'beforeunload', navigatingAway);
        } else {
            addEventHandler(window, 'unload', navigatingAway);
        };
    };

    // and now we can initialize...
    kupu.initialize();

    return kupu;
};
