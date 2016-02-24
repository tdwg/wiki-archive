/*
 * Copyright (C) 2005 ILOG http://www.ilog.fr
 * Portions Copyright (C) 2004 Damien Mandrioli and Romain Raugi
 * Portions Copyright (C) 2003-2004 Kupu Contributors. All rights reserved.
 *  
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *  
 */

function HttpRequestObject() {
  var xmlhttp;
  if (window.XMLHttpRequest) {
    try {
      xmlhttp = new XMLHttpRequest();
    } catch(e) {
      xmlhttp = false;
    }
  } else if (window.ActiveXObject) {
    try {
      xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");
    } catch(e) {
      try {
        xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
      } catch(e) {
        xmlhttp = false;
      }
    }
  }
  return xmlhttp;
}

function TWiki3StateButton(buttonid, check, command,
                           clazz) {
  /* A button that can have two states (e.g. pressed and
     not-pressed) based on CSS classes */
  this.button = getFromSelector(buttonid);
  this.command = command;
  this.parentcheck = parentFinder(check);
  this.childcheck = childFinder(check);
  this.clazz = clazz;
  this.state = 0;
  
    this.execCommand = function() {
      this.command(this, this.editor);
      this.editor.updateState();
      this.editor.focusDocument();
    };

    this.updateState = function(selNode, event) {
      var state = this.state;
      if (this.parentcheck(selNode, this, this.editor, event)) {
        state = 2;
      } else if (this.childcheck(selNode, this, this.editor, event)) {
        state = 1;
      } else {
        state = 0;
      }
      if (state != this.state) {
        this.button.className = this.clazz + state;
        this.state = state;
      }
    };
};

TWiki3StateButton.prototype = new KupuButton;

/* Exec function for formatting using a TWiki3StateButton.
 * checker - checks if a node matches criteria
 * creator - manipulates the selection so it meets the criteria
 * cleaner - manipulates a node so it doesn't meet the criteria,
 * removing the node if appropriate.
 */
function TWiki3StateToggler(checker, creator, cleaner) {
  var parentfn = parentFinder(checker);
  var childfn = childFinder(checker);

  return function (button, editor) {
    var node = editor.getSelectedNode();
    node = parentfn(node, button, editor, null);

    if (node) {
      cleaner(node);
    } else {
      node = editor.getSelectedNode();
      var c = childfn(node, button, editor, null);
      if (c) {
        for (var i = 0; i < c.length; i++) {
          cleaner(c[i]);
        }
      } else {
        creator(this.editor);
      }
    }
    editor.updateState();
  }
};

/* get a function that returns the boolean inverse of the result from the
   function passed. Used to allow parentFinder and childFinder to be used with
   KupuStateButton */
function notted(fn) {
  return function(selNode, button, editor, event) {
    return !fn(selNode, button, editor, event);
  };
}

/* Used to combine "has" functions together */
function hasOne(fn1,fn2) {
  return function(node) {
    return fn1(node) || fn2(node);
  };
}

/* get a function to find the first parent that triggers the check function */
function parentFinder(check) {
    return function(selNode, button, editor, event) {
      var node = selNode;
      if (!node) return null;
      while (node) {
        if (check(node))
          return node;
        node = node.parentNode;
      }
      return null;
    };
}

/* Get a method to check if a node has one of the specified tag names */
function hasTag(tagnames) {
  return function (node) {
    if (node.tagName) {
      var name = node.tagName.toLowerCase();
      for (var i = 0; i < tagnames.length; i++) {
        if (name == tagnames[i])
          return true;
      }
    }
    return false;
  };
}

/* Get a method that returns true if a node has a certain class */
function hasClass(clazz) {
  return function (node) {
    if (node.nodeType != 3 && node.className) {
      var c = node.className.split(' ');
      for (var i = 0; i < c.length; i++ ) {
        if (clazz == c[i]) {
          return true;
        }
      }
    }
    return false;
  };
}

/* get a function to check if a node has the given style. */
function hasStyle(style, stylevalue) {
  return function(node) {
    return (style && node.style && node.style[style] == stylevalue);
  };
};

/* get a function to create a new node over the selection,
   simply to add class */
function coverSelection(tag, clazz) {
  return function (editor) {
    var doc = editor.getInnerDocument();
    var elem = doc.createElement(tag);
    if (clazz)
      elem.className = clazz;
    _insertNode(editor, elem);
  };
}

function classCleaner(clazz) {
  return function (n) {
    _removeClass(n, clazz);
  };
}

function tagCleaner() {
  return function (n) {
    _removeNode(n);
  };
}

/* Get a function to iterate depth-first over non-text nodes below the
 * selection, and return an array of those that the "check" function
 * returned true for. If 'editor' is passed, then only nodes that are
 * part of the current selection in editor are checked. */
function childFinder(check) {
  return function(selNode, button, editor, event) {
    var c = null;
    if (!selNode) return null;
    var sel = null;
    if (editor) {
      sel = editor.getSelection();
    }
    var nodeQueue = new Array(selNode);
    while (nodeQueue.length > 0) {
      var node = nodeQueue.pop();
      if (check(node)) {
        if (!c) c = new Array();
        c.push(node);
      }
      for (var i = 0; i < node.childNodes.length; i++) {
        var kid = node.childNodes[i];
        if (kid.nodeType != 3 && (!sel || sel.containsNode(kid))) {
          nodeQueue.push(node.childNodes[i]);
        }
      }
    }
    return c;
  }
}

// remove a class, and if the tag the class is removed from matches
// and has no other class, remove the tag as well.
function TWikiRemoveClassButton(buttonid, checker, tag, clazz, cssclass) {
    this.button = getFromSelector(buttonid);
    this.onclass = cssclass;
    this.offclass = 'invisible';
    this.pressed = false;
    this.checkfunc = checker;

    this.commandfunc = function(button, editor) {
      var node = this.checkfunc(editor.getSelectedNode(), this.button,
                              editor, null);
      if (node) _removeClass(node, clazz);
    };
};

TWikiRemoveClassButton.prototype = new KupuStateButton;

// exec function that adds a tag/class over the current selection
function TWikiTagToggler(tag, clazz, checker) {
  return function (button, editor) {
    var sel = editor.getSelectedNode();
    var node = checker(sel, button, editor, null);
    if (node) {
      _removeClass(node, clazz);
    } else if (!button.pressed) {
      var doc = editor.getInnerDocument();
      var elem = doc.createElement(tag);
      elem.className = clazz;
      _insertNode(editor, elem);
    }
    editor.updateState();
  }
}

/* Move the contents of the selection into the node, and insert the
 * node in place of the selection.
 * I can't understand why this isn't a standard Kupu method!
 */
function _insertNode(editor,elem) {
  var selection = editor.getSelection();
  var cloned = selection.cloneContents();
  while (cloned.hasChildNodes()) {
    elem.appendChild(cloned.firstChild);
  };
  selection.replaceWithNode(elem, true);
};

/* Remove a node completely */
function _removeNode(node) {
    var parent = node.parentNode;
    while (node.childNodes.length) {
      var child = node.firstChild;
      child = node.removeChild(child);
      parent.insertBefore(child, node);
    };
    parent.removeChild(node);
}

/* remove the class from the node, and if the node is the given type and
 is left with no class, remove the node as well */
function _removeClass(node, clazz) {
  var c = node.className.split(' ');
  for (var i = 0; i < c.length; i++) {
    if (c[i] == clazz) {
      c.splice(i, 1);
      break;
    }
  }
  // if the node has no class, kill it completely
  if (c.length == 0) {
    _removeNode(node);
  } else {
    node.className = join(' ', c);
  }
}

function TWikiTopicDrawer(elementid, web_id, topic_id, tool) {
  this.webSelect = getFromSelector(web_id);
  this.topicSelect = getFromSelector(topic_id);
  this.element = getFromSelector(elementid);
  this.tool = tool;
  this.web = 0;

  this.changeWeb = function() {
    var w = this.webSelect.selectedIndex;
    if (w == this.web)
      return;
    this.web = w;
    if (!this.webs[w]) {
      var webname = this.webSelect.options[w].value;
      this.webs[w] = this.loadWeb(webname);
    }
    
    this.topicSelect.selectedIndex = 0;
    Sarissa.clearChildNodes(this.topicSelect);
    var topics = this.webs[w];
    for (var i = 0; i < topics.length; i++) {
      this.topicSelect.appendChild(topics[i]);
    }
  };

  this.web = this.webSelect.selectedIndex;
  this.webs = new Array(this.webSelect.childNodes.length);
  addEventHandler(this.webSelect, "change", this.changeWeb, this);

  this.loadWeb = function(web) {
    var url = this.editor.config.view_url +
      '/TWiki/WysiwygPluginTopicLister?web='+web+
      ';skin=kupuxml;contenttype=text/plain';

    var req = HttpRequestObject();
    if (!req)
      return;
    
    req.open("GET", url, false);
    req.send("");
    
    var topics = req.responseText.split("\n");
    
    /* Hack fixes for Cairo stupidity */
    if (topics.length && !topics[0].match(/\S/)) {
      topics.shift();
    }
    if (topics.length) {
      var e = topics[topics.length-1].indexOf('"}%');
      if (e >= 0) {
        topics[topics.length-1] = topics[topics.length-1].substr(0, e);
      }
    }
    
    for (i = 0; i < topics.length; i++) {
      var option = topics[i];
      var noption = document.createElement('option');
      noption.value = option;
      noption.appendChild(document.createTextNode(option));
      topics[i] = noption;
    }
    return topics;
  }

  this.save = function() {
    this.editor.resumeEditing();
    var web = this.webSelect.options[this.web].value;
    var topic = this.topicSelect.options[this.topicSelect.selectedIndex].value;
    this.tool.createWikiWord(web, topic);
    this.drawertool.closeDrawer();
  };
};

TWikiTopicDrawer.prototype = new Drawer;

/* Tool for inserting the url of an attachment into the document.
 */
function TWikiInsertAttachmentTool() {
  this.initialize = function(editor) {
    this.editor = editor;
    this.editor.logMessage('InsertAttachmentmentTool initialized');
  };
  
  this.pick = function(filename) {
    var url = this.editor.config.attachment_url_path + '/' + filename;
    var tmp = filename.lastIndexOf(".");
    if (tmp >= 0)
      tmp = filename.substring(tmp + 1, filename.length);

    var doc = this.editor.getInnerDocument();
    var elem;
    if (tmp == "jpg" || tmp == "gif" || tmp == "jpeg" ||
        tmp == "png" || tmp == "bmp") {
      elem = doc.createElement("img");
      elem.setAttribute('src', url);
      elem.setAttribute('alt', filename);
    } else {
      elem = doc.createElement("a");
      elem.setAttribute('href', url);
      var text = this.editor.getInnerDocument().createTextNode(filename);
      elem.appendChild(text);
    }
    try {
      var sel = this.editor.getSelection();
      if (sel) {
        sel.replaceWithNode(elem);
      } else {
        sel.insertNodeAtSelection(elem, 1);
      }
      this.editor.updateState();
    } catch(exception) {
      alert(e);
    }
  };
}

TWikiInsertAttachmentTool.prototype = new KupuTool;

/* UI for adding an attachment */
function TWikiNewAttachmentDrawer(drawerid, formid, tool) {
  this.element = getFromSelector(drawerid);
  this.form = getFromSelector(formid);
  this.tool = tool;

  this.save = function() {
    this.editor.resumeEditing();
    if (this.tool) {
      var path = this.form.filepath.value;
      var last = path.lastIndexOf('/');
      if (last < 0)
        last = path.lastIndexOf('\\');
      last++;
      var filename = path.substring(last);
      this.tool.pick(filename);
    }

    this.editor.updateState();
    // Close the drawer...
    this.hide();
  };
};

TWikiNewAttachmentDrawer.prototype = new Drawer;

/* Tool for inserting strings. */
function TWikiStringTool(buttonid, selectid, popupid){
  this.strbutton = getFromSelector(buttonid);
  this.strwindow = getFromSelector(popupid);
  this.strselect = getFromSelector(selectid);

  this.initialize = function(editor) {
    /* attach events handlers and hide images' panel */
    this.editor = editor;
    addEventHandler(this.strbutton, "click", this.openStringChooser, this);
    addEventHandler(this.strselect, "change", this.chooseString, this);
    this.hide();
  };

  this.updateState = function(selNode) {
    /* update state of the chooser */
    this.hide();
  };

  this.openStringChooser = function() {
    /* open the chooser pane */
    this.show();
  };
  
  this.show = function() {
    /* show the chooser */
    this.strselect.selectedIndex = 0;
    this.strwindow.style.display = "block";
  };

  this.hide = function() {
    /* hide the chooser */
    this.strwindow.style.display = "none";
  };
  
  this.chooseString = function(evt) {
    // event handler for choosing the string
    var string = this.strselect.options[this.strselect.selectedIndex].value;
    var doc = this.editor.getInnerDocument();
    var elem;

    elem = doc.createTextNode(string);

    // stomp anything already selected
    this.editor.insertNodeAtSelection(elem);
    this.editor.updateState();
  };
}

TWikiStringTool.prototype = new KupuTool;

/* Tool for inserting smilies. The smilies are collected in a div, which
 * is shown and hidden as required to give the effect of a popup panel.
 * The reson this is not a drawer is that it was implemented before
 * drawers existed (I think)  */
function TWikiIconsTool(buttonid, popupid){
  this.imgbutton = getFromSelector(buttonid);
  this.imwindow = getFromSelector(popupid);
  
  this.initialize = function(editor) {
    /* attach events handlers and hide images' panel */
    this.editor = editor;
    addEventHandler(this.imgbutton, "click", this.openImageChooser, this);
    addEventHandler(this.imwindow, "click", this.chooseImage, this);
    this.hide();
    this.editor.logMessage('Icons tool initialized');
  };

  this.updateState = function(selNode) {
    /* update state of the chooser */
    this.hide();
  };

  this.openImageChooser = function() {
    /* open the chooser pane */
    this.show();
  };
  
  this.show = function() {
    /* show the chooser */
    this.imwindow.style.display = "block";
  };

  this.hide = function() {
    /* hide the chooser */
    this.imwindow.style.display = "none";
  };

  this.chooseImage = function(evt) {
    /* insert chosen image (delegate to createImage) */
    // event handler for choosing the color
    var target = _SARISSA_IS_MOZ ? evt.target : evt.srcElement;
    this.createImage(target);
    this.hide();
  };

  this.createImage = function(template) {
    var doc = this.editor.getInnerDocument();
    var src = template.getAttribute('src');
    if( !src || src.length == 0) {
      return;
    }
    var img = doc.createElement('img');
    img.setAttribute('src', template.getAttribute('src'));
    img.setAttribute('alt', template.getAttribute('alt'));
    img.classname = template.classname;
    try {
      img = this.editor.insertNodeAtSelection(img);
    } catch( exception ) {
      this.imwindow.style.display = "none";
    };
  };
}

TWikiIconsTool.prototype = new KupuTool;
 
/* Tool for inserting a new NOP region, around whatever is selected */
/* if already in a region of that type, remove the region */
function TWikiNOPTool(buttonid){
  this.button = getFromSelector(buttonid);

  this.initialize = function(editor) {
    /* tool initialization : nothing */
    this.editor = editor;
    addEventHandler(this.button, "click", this.insert, this);
    this.editor.logMessage('NOP tool initialized');
  };
 
  this.insert = function() {
    var doc = this.editor.getInnerDocument();
    var elem = doc.createElement('span');
    elem.setAttribute('class', 'TMLnop');
    _insertNode(this.editor, elem);
    this.editor.updateState();
  };
}


TWikiNOPTool.prototype = new KupuTool;

/* Tool for inserting wikiwords */
function TWikiWikiWordTool() {
  this.createWikiWord = function(web, topic) {
    var url = this.editor.config.view_url+web+"/"+topic;
    this.createLink(url, null, null, null, topic);
  };
  this.createContextMenuElements = function(selNode, event) {
    return [];
  };
};

TWikiWikiWordTool.prototype = new LinkTool;

function TWikiHandleSubmit(kupu) {
  //alert("Fixing spans");
  FixBoldItalic(kupu);

  var form = getFromSelector('twiki-main-form');

  kupu.content_changed = 0; // choke the unload handler

  // the default filterContent calls xhtmlvalid, which does all
  // sorts of naughties, such as stripping comments. Because the editor
  // should only be generating valid HTML, and TWiki only generates
  // valid XHTML (hah!) we can ignore this cleanup step.
  kupu._filterContent = function (doc) {
    return doc;
  };

  //alert("Preparing form");
  // use Kupu to create the 'text' field in the form
  kupu.prepareForm(form, 'text');

  //alert("Stripping");
  if (kupu.getBrowserName() == "IE") {
    // If we don;t remove ^M's, the server converts them the LFs, which
    // ends up giving us twice as many LFs as we wanted.
    var ta = form.lastChild;
    var text = ta.lastChild.data;
    var clean = '';
    for (var i = 0; i < text.length; i++) {
      if (text.charAt(i) != '\r') {
        clean += text.charAt(i);
      }
    }
    ta.replaceChild(document.createTextNode(clean), ta.lastChild);
  }
  //alert("Submitting");

  // we *do not* submit here
  return form;
}

/*
 * A submit can come from several places; from links inside the form
 * (replace form and add form) and from the Kupu save button, which is
 * redirected to the form. We need to create the 'text'
 * field for all these operations.
 *
 * This function can be called in a number of different ways:
 * 1. As the onSubmit handler for the form, when triggered by a click
 *    on a type="submit" input in the form (e.g. replace form)
 * 2. Just before a form.submit() call, such as the one done for the
 *    save button
 */
function TWikiVetoIfChanged(kupu, isSave) {
  if (!kupu) {
    // nasty hack, but I don't know how else to do it
    kupu = window.drawertool.editor;
  }
  var ok;
  var msg = 'You have unsaved changes.\n'+
    'Are you sure you want to navigate away from this page?\n';
  if( isSave ) {
    kupu.config.reload_src = 0;
    ok = false;
    if( kupu.content_changed ) {
      // Form submission will *save* the topic
      msg += 'Cancel will DISCARD your changes (forever!).\n'+
        'OK will SAVE your changes.';
      ok = confirm(msg);
    }
  } else {
    // Form submission will *discard* the changes
    ok = true;
    if( kupu.content_changed ) {
      msg += 'OK will DISCARD your changes.';
      ok = confirm(msg);
    }
  }
  if (ok) {
    // Call the submit handler, as it's not called by the submit() method
    var form = TWikiHandleSubmit(kupu);
    form.submit();
  }
  // always return false to veto the submit, if it came from a form button
  return false;
}

function MIMEset(name, value, boundary) {
  var body = '--' + boundary + '\r\n';
  body += 'Content-Disposition: form-data; name="' + name + '"' + '\r\n\r\n';
  body += value + '\r\n';
  return body;
}

function stringify(node) {
  if (!node)
    return "NULL";
  if (node.nodeName == '#text') {
    var text = node.nodeValue;
    var naked = '';
    for (var i = 0; i < text.length; i++) {
      var s = text.charAt(i);
      if (s < ' ') {
        naked += '%' + text.charCodeAt(i);
      } else {
        naked += s;
      }
    }
    return naked;
  }
  var nn = node.nodeName;
  var str = '<' + nn;
  for (var i = 0; i < node.attributes.length; i++) {
    var attr = node.attributes[i];
    if(attr.nodeValue != null) {
      str += ' '+attr.nodeName+'='+attr.nodeValue;
    }
  }
  str += '>';
  var node = node.firstChild;
  while (node) {
    str = str + stringify(node);
    node = node.nextSibling;
  }
  return str + '</'+nn+'>';
}

function TWikiColorChooserTool(fgcolorbuttonid, colorchooserid) {
    /* the colorchooser */
    
    this.fgcolorbutton = getFromSelector(fgcolorbuttonid);
    this.ccwindow = getFromSelector(colorchooserid);
    this.command = null;

    this.initialize = function(editor) {
        /* attach the event handlers */
        this.editor = editor;
        
        this.createColorchooser(this.ccwindow);

        addEventHandler(this.fgcolorbutton, "click", this.openFgColorChooser, this);
        addEventHandler(this.ccwindow, "click", this.chooseColor, this);

        this.hide();

        this.editor.logMessage('Colorchooser tool initialized');
    };

    this.updateState = function(selNode) {
        /* update state of the colorchooser */
        this.hide();
    };

    this.openFgColorChooser = function() {
        /* event handler for opening the colorchooser */
        this.command = "forecolor";
        this.show();
    };

    this.chooseColor = function(event) {
        /* event handler for choosing the color */
        var target = _SARISSA_IS_MOZ ? event.target : event.srcElement;
        var cell = this.editor.getNearestParentOfType(target, 'td');
        this.editor.execCommand(this.command, cell.getAttribute('bgColor'));
        this.hide();
    
        this.editor.logMessage('Color chosen');
    };

    this.show = function(command) {
        /* show the colorchooser */
        this.ccwindow.style.display = "block";
    };

    this.hide = function() {
        /* hide the colorchooser */
        this.command = null;
        this.ccwindow.style.display = "none";
    };

    this.createColorchooser = function(table) {
        /* create the colorchooser table */
        var cols = new Array( 
 "black", "red", "orange", "yellow", "greenyellow", "lime", "aquamarine", "cyan", "blue", "blueviolet", "fuchsia", "hotpink",
 "dimgray", "firebrick", "darkorange", "gold", "yellowgreen", "green", "turquoise", "deepskyblue", "mediumblue", "darkviolet", "violetred", "deeppink",
 "darkgray", "lightcoral", "goldenrod", "lightyellow", "olivedrab", "limegreen", "mediumturquoise", "lightskyblue", "darkslateblue", "thistle", "orchid", "palevioletred",
 "silver", "rosybrown", "darkkhaki", "khaki", "olive", "darkgreen", "lightseagreen", "steelblue", "navy", "indigo", "purple", "crimson"
        );
        table.setAttribute('id', 'kupu-colorchooser-table');
        table.style.borderWidth = '2px';
        table.style.borderStyle = 'solid';
        table.style.position = 'absolute';
        table.style.cursor = 'default';
        table.style.display = 'none';

        var tbody = document.createElement('tbody');

        for (var i=0; i < 4; i++) {
            var tr = document.createElement('tr');
            for (var j = 0; j < 12; j++) {
              var color = cols[i * 12 + j];;
              var td = document.createElement('td');
              td.setAttribute('bgColor', color);
              td.style.borderWidth = '1px';
              td.style.borderStyle = 'solid';
              td.style.fontSize = '1px';
              td.style.width = '10px';
              td.style.height = '10px';
              var text = document.createTextNode('\u00a0');
              td.appendChild(text);
              tr.appendChild(td);
            }
            tbody.appendChild(tr);
        }
        table.appendChild(tbody);

        return table;
    };
}

TWikiColorChooserTool.prototype = new KupuTool;

// only check max if max > min
function twikiVerifyNumber(val,min,max) {
  var error = "";

  if (error.length == 0 && isNaN(val)) {
    error = name + " is not a number";
  }
  if (error.length == 0 && val < min) {
    error = name + " must be >= " + min;
  }
  if (error.length == 0 && max > min && val > max) {
    error = name + " must be <= " + max;
  }

  if (error.length > 0) {
    alert(error);
    return false;
  };

  return true;
}

function TWikiRemoveElementButton(buttonid, element_name, cssclass) {
    this.button = getFromSelector(buttonid);

    this.execCommand = function() {
      this.button.style.display = 'none';
      this.editor.focusDocument();
      this.editor.removeNearestParentOfType(this.editor.getSelectedNode(),
                                            element_name);
    };

    this.updateState = function(selNode, event) {
        if (this.checkfunc(selNode, this, this.editor, event)) {
          this.button.style.display = 'none';
        } else {
          this.button.style.display = 'inline';
        };
    };

    this.checkfunc = function(currnode, button, editor, event) {
        var element = editor.getNearestParentOfType(currnode, element_name);
        return (element ? false : true);
    };
};

TWikiRemoveElementButton.prototype = new KupuButton;

function TWikiTableTool() {
  this.createTable = function(rows, cols, makeHeader, tableclass) {
    if (!twikiVerifyNumber(rows,1,-1) ||
        !twikiVerifyNumber(cols,1,-1))
      return;
    var args = new Array();
    args.push(rows);
    args.push(cols);
    args.push(makeHeader);
    args.push(tableclass);
    var table = TWikiTableTool.prototype.createTable.apply(this, args);
    table.cellspacing = 1;
    table.cellpadding = 0;
    table.border = 1;
  };
}

TWikiTableTool.prototype = new TableTool;

/* Invoked when a file has been uploaded, as the IFRAME finishes
 * loading. Should be possible to make this smarter - e.g. by
 * inspecting the result status. */
function uploadComplete() {
  if (typeof drawertool  != "undefined" && drawertool.current_drawer)
    // close the dialog
    drawertool.current_drawer.save();
}

// For some reason, the firefox implementation of Kupu filters
// out style="font-weight: bold" and other attributes on save.
// We convert them to b and i elements to avoid this effect.
function FixBoldItalic(editor) {
  var doc = editor.getInnerDocument();
  _FixBoldItalic(doc, doc.documentElement);
}

// Assume the font styles attributes will be stripped out by the
// XHTML validation filter
function _FixBoldItalic(doc, node) {
  if (node.style && node.style.fontWeight == 'bold') {
    var e = doc.createElement('b');
    node.parentNode.replaceChild(e, node);
    e.appendChild(node);
    node.style.fontWeight = null;
  }
  if (node.style && node.style.fontStyle == 'italic') {
    var e = doc.createElement('i');
    node.parentNode.replaceChild(e, node);
    e.appendChild(node);
    node.style.fontStyle = null;
  }
  for (var i = 0; i < node.childNodes.length; i++) {
    _FixBoldItalic(doc, node.childNodes[i]);
  }
}

function twikiTwist(id, show) {
  var off = getFromSelector(id+'_off');
  var on = getFromSelector(id+'_on');
  if (show) {
    on.style.display = 'block';
    off.style.display = 'none';
  } else {
    on.style.display = 'none';
    off.style.display = 'block';
  }
}
