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
 * TWiki-specific customisation of kupuinit.js
 */

function initKupu(iframe) {

    // first we create a logger
    var l = new PlainLogger('kupu-toolbox-debuglog', 20);
    
    // now some config values
    var conf = loadDictFromXML(document, 'kupuconfig');
    
    // the we create the document, hand it over the id of the iframe
    var doc = new KupuDocument(iframe);
    
    // now we can create the controller
    var kupu = new KupuEditor(doc, conf, l);

    var contextmenu = new ContextMenu();
    kupu.setContextMenu(contextmenu);

    // now we can create a UI object which we can use from the UI
    var ui = new KupuUI('kupu-tb-styles');

    // override the setTextStyle method
    var preUp = parentFinder(hasTag(new Array('pre')));
    var preDown = childFinder(hasTag(new Array('pre')));

    var superstyle = ui.setTextStyle;
    ui.setTextStyle = function(style) {
      var verbatim = false;
      style = style.toUpperCase();
      if (kupu.getBrowserName() == "IE") {
        kupu.execCommand('formatblock', '<'+style+'>');
      } else {
        kupu.execCommand('formatblock', style);
      }
      if (style == 'PRE') {
        // Add class to PRE nodes
        var selNode = kupu.getSelectedNode();
        var preNode = preUp(selNode);
        if (preNode) {
          preNode.className = 'TMLverbatim';
        } else {
          var preNodes = preDown(selNode, null, kupu);
          for (var i = 0; i < preNodes.length; i++) {
            preNodes[i].className = 'TMLverbatim';
          }
        }
      }
    }
    // the ui must be registered to the editor like a tool so it can be
    // notified of state changes
    kupu.registerTool('ui', ui); // XXX Should this be a different method?

    // var boldcheck = hasOne(hasTag(new Array('b', 'strong')),
    //                    hasStyle('font-weight', 'bold'));
    var boldcheck = hasTag(new Array('b', 'strong'));
    var boldexec = function(button, editor) {
      editor.execCommand('bold');
    };
    var boldbutton = new TWiki3StateButton('twiki-bold-button', 
                                           boldcheck,
                                           boldexec,
                                           'twiki-bold-button');
    kupu.registerTool('boldbutton', boldbutton);

    //var italicscheck = hasOne(hasTag(new Array('i', 'em')),
    //hasStyle('font-style', 'italic'));
    var italicscheck = hasTag(new Array('i', 'em'));
    var italicsexec = function(button, editor) {
      editor.execCommand('italic');
    };
    var italicsbutton = new TWiki3StateButton('twiki-italic-button', 
                                              italicscheck, 
                                              italicsexec,
                                              'twiki-italic-button');
    kupu.registerTool('italicsbutton', italicsbutton);

    /*
    var codetags = new Array('tt', 'code');
    var codecheck = hasTag(codetags);
    var codecreate = coverSelection('code');
    var codeclean = tagCleaner('code');
    var codeexec = TWiki3StateToggler(codecheck, codecreate, codeclean );
    var codebutton = new TWiki3StateButton('twiki-code-button', 
                                           codecheck, codeexec,
                                           'twiki-code-button');
    kupu.registerTool('codebutton', codebutton);
    */

    var nopcheck = hasClass('TMLnop');
    var nopcreator = coverSelection('span', 'TMLnop');
    var nopcleaner = classCleaner('TMLnop');
    var nopexec = TWiki3StateToggler(nopcheck, nopcreator, nopcleaner);
    var nopbutton = new TWiki3StateButton('twiki-nop-button', 
                                          nopcheck, nopexec,
                                          'twiki-nop-button');
    kupu.registerTool('nopbutton', nopbutton);

    // Icon picker
    var twikiiconstool = new TWikiIconsTool('twiki-icons-button', 
                                            'twiki-icons');
    kupu.registerTool('twikiicons', twikiiconstool);

    // String picker
    var twikistringtool = new TWikiStringTool('twiki-strings-button', 
                                              'twiki-strings-select',
                                              'twiki-strings');
    kupu.registerTool('twikistringtool', twikistringtool);

    var execCommand = function(c) {
      return function(button, editor) {
        editor.execCommand(c);
      };
    };
    var outdentbutton = new KupuButton('kupu-outdent-button',
                                       execCommand('outdent'));
    kupu.registerTool('outdentbutton', outdentbutton);

    var indentbutton = new KupuButton('kupu-indent-button',
                                      execCommand('indent'));
    kupu.registerTool('indentbutton', indentbutton);

    var undobutton = new KupuButton('kupu-undo-button',
                                    execCommand('undo'));
    kupu.registerTool('undobutton', undobutton);

    var redobutton = new KupuButton('kupu-redo-button', execCommand('redo'));
    kupu.registerTool('redobutton', redobutton);

    var removelinkbutton =
      new TWikiRemoveElementButton('kupu-removelink-button',
                                  'a',
                                  'kupu-removelink');
    kupu.registerTool('removelinkbutton', removelinkbutton);

    // add some tools
    var colorchoosertool = new TWikiColorChooserTool('kupu-forecolor-button',
                                                     'kupu-colorchooser');
    kupu.registerTool('colorchooser', colorchoosertool);

    var listtool = new ListTool('kupu-list-ul-addbutton',
                                'kupu-list-ol-addbutton',
                                'kupu-ulstyles', 'kupu-olstyles');

    // Override methods that enable the bullet type selection box
    // Kupu doesn't do OO properly, so this is harder to do than it needs to be
    listtool.super_handleStyles = listtool._handleStyles;
    listtool._handleStyles = function(currnode, onselect, offselect) {
      listtool.super_handleStyles(currnode, onselect, offselect);
      onselect.style.display = "none";
    };
    listtool.super_addList = listtool.addList;
    listtool.addList = function(command) {
      listtool.super_addList(command);
      listtool.ulselect.style.display = "none";
    };

    kupu.registerTool('listtool', listtool);
    
    /*
    var definitionlisttool = new DefinitionListTool('kupu-list-dl-addbutton');
    kupu.registerTool('definitionlisttool', definitionlisttool);
    */
    // shows the path to the current element in the status bar
    var showpathtool = new ShowPathTool();
    kupu.registerTool('showpathtool', showpathtool);

    var sourceedittool = new SourceEditTool('kupu-source-button',
                                            'kupu-editor-textarea');
    kupu.registerTool('sourceedittool', sourceedittool);

    var zoom = new KupuZoomTool('kupu-zoom-button');
    kupu.registerTool('zoomtool', zoom);

    // Save button
    var savebutton = document.getElementById('kupu-save-button');
    function submitForm() {
      // Explicitly call the form submit handler; it is not called by submit()
      var form = TWikiHandleSubmit(kupu);
      form.submit();
    }
    addEventHandler(savebutton, 'click', submitForm, kupu);

    var cancelbutton = document.getElementById('twiki-cancel-button');
    function cancelEdit() {
      var url = conf.cancel;
      window.document.location = conf.cancel;
    }
    addEventHandler(cancelbutton, 'click', cancelEdit, kupu);

    // Tools with Drawers...

    var drawertool = new DrawerTool();
    kupu.registerTool('drawertool', drawertool);

    // Function that returns function to open a drawer
    var opendrawer = function(drawerid) {
        return function(button, editor) {
            drawertool.openDrawer(drawerid);
        };
    };

    // Link drawer

    var linktool = new NoContextMenu( new LinkTool() );
    kupu.registerTool('linktool', linktool);

    var linkdrawerbutton = new KupuButton('kupu-linkdrawer-button',
                                          opendrawer('linkdrawer'));
    kupu.registerTool('linkdrawerbutton', linkdrawerbutton);

    var linkdrawer = new LinkDrawer('kupu-linkdrawer', linktool);
    drawertool.registerDrawer('linkdrawer', linkdrawer);

    // Table drawer
    var tabletool = new TWikiTableTool();
    kupu.registerTool('tabletool', tabletool);

    var tabledrawerbutton = new KupuButton('kupu-tabledrawer-button',
                                           opendrawer('tabledrawer'));
    kupu.registerTool('tabledrawerbutton', tabledrawerbutton);

    var tabledrawer = new TableDrawer('kupu-tabledrawer', tabletool);
    drawertool.registerDrawer('tabledrawer', tabledrawer);

    // WikiWord drawer
    var wikiwordtool = new TWikiWikiWordTool(linktool);
    kupu.registerTool('wikiwordtool', wikiwordtool);

    var wikiworddrawerbutton = new KupuButton('twiki-wikiworddrawer-button',
                                              opendrawer('wikiworddrawer'));
    kupu.registerTool('wikiworddrawerbutton', wikiworddrawerbutton);

    var wikiworddrawer = new TWikiTopicDrawer('twiki-wikiworddrawer',
                                              'twiki-wikiweb-select',
                                              'twiki-wikiword-select',
                                              wikiwordtool);
    drawertool.registerDrawer('wikiworddrawer', wikiworddrawer);

    // Attachments drawer
    var newImageTool = new TWikiInsertAttachmentTool();
    kupu.registerTool('insertImage', newImageTool);
    
    var newImageButton = new KupuButton('twiki-image-button',
                                        opendrawer('newImageDrawer'));
    kupu.registerTool('newImageButton', newImageButton);

    var newImageDrawer =
      new TWikiNewAttachmentDrawer('twiki-new-attachment-drawer',
                                   'twiki-upload-form',
                                   newImageTool);
    drawertool.registerDrawer('newImageDrawer', newImageDrawer);

    // New attachment drawer
    /* 
       var newAttButton = new KupuButton('twiki-attach-button',
       opendrawer('newAttDrawer'));
       kupu.registerTool('newAttButton', newAttButton);

       var newAttDrawer =
       new TWikiNewAttachmentDrawer('twiki-new-attachment-drawer',
       'twiki-upload-form',
       null);
       drawertool.registerDrawer('newAttDrawer', newAttDrawer);
    */

    //kupu.registerFilter(new PreSaveFilter());

    return kupu;
};
