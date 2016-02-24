var toShow = new Array();
var toHide = new Array();
var COOKIE_PREFIX = "PatternEdit";
var COOKIE_EXPIRES = 365; // days
var EDITBOX_ID = "topic";
var SIGNATURE_BOX_ID = "sig";
var EDITBOX_HOLDER_ID = "formHolder";
// edit box rows
var EDITBOX_COOKIE_ROWS_ID = "TextareaRows";
var EDITBOX_CHANGE_STEP_SIZE = 4;
var EDITBOX_MIN_ROWCOUNT = 4;
// edit box font style
var EDITBOX_COOKIE_FONTSTYLE_ID = "TextareaFontStyle";
var EDITBOX_FONTSTYLE_MONO = "mono";
var EDITBOX_FONTSTYLE_PROPORTIONAL = "proportional";
var EDITBOX_FONTSTYLE_MONO_STYLE = "twikiEditboxStyleMono";
var EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE = "twikiEditboxStyleProportional";
var EDITBOX_COOKIE_FONTSTYLE_ID = "TextareaFontstyle";

function initForm() {
	try { document.main.text.focus(); } catch (er) {}
	
	initTextAreaHeight();
	initTextAreaFontStyle();
	unhideTextArea();
	
	var i, ilen = toShow.length;
	var elem;
	for (i = 0; i < ilen; ++i) {
		if (dom) {
			elem = document.getElementById(toShow[i]);
			if (elem) elem.style.display="inline";
		} else if (ie4) {
			document.all[toShow[i]].style.display="inline";
		} else if (ns4) {
			document.layers[toShow[i]].style.display="inline";
		}
	}
	ilen = toHide.length;
	for ( i = 0; i < toHide.length; ++i) {
		if (dom) {
			elem = document.getElementById(toHide[i]);
			if (elem) elem.style.display="none";
		} else if (ie4) {
			document.all[toHide[i]].style.display="none";
		} else if (ns4) {
			document.layers[toHide[i]].style.display="none";
		}
	}
}

/**
Sets the height of the edit box to height read from cookie.
*/
function initTextAreaHeight() {
	var cookie  = readCookie(COOKIE_PREFIX + EDITBOX_COOKIE_ROWS_ID);
	if (!cookie) return;
	setEditBoxHeight( parseInt(cookie) );
}

/**
Sets the font style (monospace or proportional space) of the edit box to style read from cookie.
*/
function initTextAreaFontStyle() {
	var cookie  = readCookie(COOKIE_PREFIX + EDITBOX_COOKIE_FONTSTYLE_ID);
	if (!cookie) return;
	setEditBoxFontStyle( cookie );
}

/**
Now that all edit box properties have been set, the hidden text area holder may unhide.
*/
function unhideTextArea() {
	var elem = document.getElementById(EDITBOX_HOLDER_ID);
	if (elem) elem.style.display = "block";
}

/**
Disables the use of ESCAPE in the edit box, because some browsers will interpret this as cancel and will remove all changes.
*/
function handleKeyDown(e) {
	if (!e) e = window.event;
	var code;
	if (e.keyCode) code = e.keyCode;
	if (code==27) return false;
	return true;
}

function checkAll( theButton, theButtonOffset, theNum, theCheck ) {
	// find button element index
	var i, j = 0;
	for (i = 0; i <= document.main.length; ++i) {
		if( theButton == document.main.elements[i] ) {
			j = i;
			break;
		}
	}
	// set/clear all checkboxes
	var last = j+theButtonOffset+theNum;
	for(i = last-theNum; i < last; ++i) {
		document.main.elements[i].checked = theCheck;
	}
}

/**
Changes the height of the editbox textarea.
param inDirection : -1 (decrease) or 1 (increase).
If the new height is smaller than EDITBOX_MIN_ROWCOUNT the height will become EDITBOX_MIN_ROWCOUNT.
Each change is written to a cookie.
*/
function changeEditBox(inDirection) {
	var rowCount = document.getElementById(EDITBOX_ID).rows;
	rowCount += (inDirection * EDITBOX_CHANGE_STEP_SIZE);
	rowCount = (rowCount < EDITBOX_MIN_ROWCOUNT) ? EDITBOX_MIN_ROWCOUNT : rowCount;
	setEditBoxHeight(rowCount);
	writeCookie(COOKIE_PREFIX + EDITBOX_COOKIE_ROWS_ID, rowCount, COOKIE_EXPIRES);
	return false;
}

/**
Sets the height of the exit box text area.
param inRowCount: the number of rows
*/
function setEditBoxHeight(inRowCount) {
	document.getElementById(EDITBOX_ID).rows = inRowCount;
}

/**
Sets the font style of the edit box and the signature box. The change is written to a cookie.
param inFontStyle: either EDITBOX_FONTSTYLE_MONO or EDITBOX_FONTSTYLE_PROPORTIONAL
*/
function setEditBoxFontStyle(inFontStyle) {
	if (inFontStyle == EDITBOX_FONTSTYLE_MONO) {
		replaceClass(document.getElementById(EDITBOX_ID), EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE, EDITBOX_FONTSTYLE_MONO_STYLE);
		replaceClass(document.getElementById(SIGNATURE_BOX_ID), EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE, EDITBOX_FONTSTYLE_MONO_STYLE);
		writeCookie(COOKIE_PREFIX + EDITBOX_COOKIE_FONTSTYLE_ID, inFontStyle, COOKIE_EXPIRES);
		return;
	}
	if (inFontStyle == EDITBOX_FONTSTYLE_PROPORTIONAL) {
		replaceClass(document.getElementById(EDITBOX_ID), EDITBOX_FONTSTYLE_MONO_STYLE, EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE);
		replaceClass(document.getElementById(SIGNATURE_BOX_ID), EDITBOX_FONTSTYLE_MONO_STYLE, EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE);
		writeCookie(COOKIE_PREFIX + EDITBOX_COOKIE_FONTSTYLE_ID, inFontStyle, COOKIE_EXPIRES);
		return;
	}
}

addLoadEvent(initForm);