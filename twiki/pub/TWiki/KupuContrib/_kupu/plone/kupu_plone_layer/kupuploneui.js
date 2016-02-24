/*****************************************************************************
 *
 * Copyright (c) 2003-2005 Kupu Contributors. All rights reserved.
 *
 * This software is distributed under the terms of the Kupu
 * License. See LICENSE.txt for license text. For a list of Kupu
 * Contributors see CREDITS.txt.
 *
 *****************************************************************************/

// $Id: kupuploneui.js 15966 2005-08-11 15:16:18Z duncan $

function PloneKupuUI(textstyleselectid) {
    this.tsselect = getFromSelector(textstyleselectid);
    this.otherstyle = null;
    this.styles = {};
    var styles = this.styles; // use an object here so we can use the 'in' operator later on
    
    function cleanStyles(options) {
        for (var i=0; i < options.length; i++) {
            var style = options[i].value;
            if (style.indexOf('|') > -1) {
                var split = style.split('|');
                style = split[0].toLowerCase() + "|" + split[1];
            };
            styles[style] = i;
        };
    }
    cleanStyles(this.tsselect.options);

    this.enableOptions = function(inTable) {
        var options = this.tsselect.options;
        for (var i = 0; i < options.length; i++) {
            var opt = options[i];
            if (/^t[rdh]\b/.test(opt.value)) {
                opt.disabled = inTable ? '' : 'disabled';
            }
        }
    }

    this.setIndex = function(currnode, tag, index) {
        var className = currnode.className;
        this.styletag = tag;
        this.classname = className;
        var style = tag+'|'+className;
        if (style in styles) {
            return styles[style];
        } else if (!className && tag in styles) {
            return styles[tag];
        }
        return index;
    }
    this.nodeStyle = function(node) {
        var currnode = node;
        var index = -1;
        var styles = this.styles;
        var options = this.tsselect.options;
        this.styletag = undefined;
        this.classname = '';
        this.intable = false;

        while (currnode) {
            if (currnode.nodeType==1) {
                var tag = currnode.tagName;
                tag = tag.toLowerCase();
                
                if (/^body$/.test(tag)) {
                    if (!this.styletag) {
                        // Force style setting
                        this.setTextStyle(options[0].value, true);
                        return 0;
                    }
                    break;
                }
                if (/^(p|div|h.|ul|ol|dl|menu|dir|pre|blockquote|address|center)$/.test(tag)) {
                    index = this.setIndex(currnode, tag, index);
                }
                if (/^t.$/.test(tag)) {
                    if (index==-1) {
                        index = this.setIndex(currnode, tag, index);
                    }
                    this.intable = true;
                    return index; // Stop processing if in a table
                }
            }
            currnode = currnode.parentNode;
        }
        return index;
    }
    
    this.updateState = function(selNode) {
        /* set the text-style pulldown */

        // first get the nearest style
        // search the list of nodes like in the original one, break if we encounter a match,
        // this method does some more than the original one since it can handle commands in
        // the form of '<style>|<classname>' next to the plain
        // '<style>' commands
        var index = undefined;
        var mixed = false;
        var styletag, classname;

        var selection = this.editor.getSelection();

        for (var el=selNode.firstChild; el; el=el.nextSibling) {
            if (el.nodeType==1 && selection.containsNode(el)) {
                var i = this.nodeStyle(el);
                if (index===undefined) {
                    index = i;
                    styletag = this.styletag;
                    classname = this.classname;
                }
                if (index != i || styletag!=this.styletag || classname != this.classname) {
                    mixed = true;
                    break;
                }
            }
        };

        if (index===undefined) {
            index = this.nodeStyle(selNode);
        }

        if (this.otherstyle) {
            this.tsselect.removeChild(this.otherstyle);
            this.otherstyle = null;
        }
        this.enableOptions(this.intable);

        if (index < 0 || mixed) {
            var caption = mixed ? 'Mixed styles' :
                'Other: ' + this.styletag + ' '+ this.classname;

            if (!this.otherstyle) {
                var opt = document.createElement('option');
                this.tsselect.appendChild(opt);
                this.otherstyle = opt;
                this.otherstyle.text = caption;
            }

            index = this.tsselect.length-1;
        }
        this.tsselect.selectedIndex = Math.max(index,0);
    };
  
    this._cleanNode = function(node) {
            /* Clean up a block style node (e.g. P, DIV, Hn)
             * Remove trailing whitespace, then also remove up to one
             * trailing <br>
             * If the node is now empty, remove the node itself.
             */
        var len = node.childNodes.length;
        function stripspace() {
            var c;
            while ((c = node.lastChild) && c.nodeType==3 && /^\s*$/.test(c.data)) {
                node.removeChild(c);
            }
        }
        stripspace();
        var c = node.lastChild;
        if (c && c.nodeType==1 && c.tagName=='BR') {
            node.removeChild(c);
        }
        stripspace();
        if (node.childNodes.length==0) {
            node.parentNode.removeChild(node);
        };
    }

    this._cleanCell = function(eltype, classname) {
        var selNode = this.editor.getSelectedNode();
        var el = this.editor.getNearestParentOfType(selNode, eltype);
        if (!el) {
            // Maybe changing type
            el = this.editor.getNearestParentOfType(selNode, eltype=='TD'?'TH':'TD');
        }
        if (!el) return;

        // Remove formatted div or p from a cell
        var node, nxt, n;
        for (node = el.firstChild; node;) {
            if (node.nodeType==1 && /div|p/i.test(node.tagName)) {
                for (var n = node.firstChild; n;) {
                    var nxt = n.nextSibling;
                    el.insertBefore(n, node); // Move nodes out of div
                    n = nxt;
                }
                nxt = node.nextSibling;
                el.removeChild(node);
                node = nxt;
            } else {
                node = node.nextSibling;
            }
        }
        if (eltype != el.tagName) {
            // Change node type.
            var node = el.ownerDocument.createElement(eltype);
            var parent = el.parentNode;
            parent.insertBefore(node, el);
            while (el.firstChild) {
                node.appendChild(el.firstChild);
            }
            parent.removeChild(el);
            el = node;
        }
        // now set the classname
        if (classname) {
            el.className = classname;
        } else {
            el.removeAttribute(el.className ?"className":"class");
        }
        
    }

    this._setClass = function(el, classname) {
        var parent = el.parentNode;
        if (parent.tagName=='DIV') {
                // fixup buggy formatting
            var gp = parent.parentNode;
            if (el != parent.firstChild) {
                var previous = parent.cloneNode(false);
                while (el != parent.firstChild) {
                    previous.appendChild(parent.firstChild);
                }
                gp.insertBefore(previous, parent);
                this._cleanNode(previous);
            }
            gp.insertBefore(el, parent);
            this._cleanNode(el);
            this._cleanNode(parent);
        }
        // now set the classname
        if (classname) {
            el.className = classname;
        } else {
            el.removeAttribute(el.className ?"className":"class");
        }
    }
    this.setTextStyle = function(style, noupdate) {
        /* parse the argument into a type and classname part
           generate a block element accordingly 
*/
        var classname = '';
        var eltype = style.toUpperCase();
        if (style.indexOf('|') > -1) {
            style = style.split('|');
            eltype = style[0].toUpperCase();
            classname = style[1];
        };

        var command = eltype;
        // first create the element, then find it and set the classname
        if (this.editor.getBrowserName() == 'IE') {
            command = '<' + eltype + '>';
        };
        if (/T[RDH]/.test(eltype)) {
            this._cleanCell(eltype, classname);
        }
        else {
            this.editor.getDocument().execCommand('formatblock', command);

            // now get a reference to the element just added
            var selNode = this.editor.getSelectedNode();
            var el = this.editor.getNearestParentOfType(selNode, eltype);
            if (el) {
                this._setClass(el, classname);
            } else {
                var selection = this.editor.getSelection();
                var elements = selNode.getElementsByTagName(eltype);
                for (var i = 0; i < elements.length; i++) {
                    el = elements[i];
                    if (selection.containsNode(el)) {
                        this._setClass(el, classname);
                    }
                }
            }
        }
        if (el) {
            this.editor.getSelection().selectNodeContents(el);
        }
        if (!noupdate) {
            this.editor.updateState();
        }
    };
};

PloneKupuUI.prototype = new KupuUI;
