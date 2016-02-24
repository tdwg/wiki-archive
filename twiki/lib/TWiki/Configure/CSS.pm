use strict;

package TWiki::Configure::CSS;

use vars qw( $css );

sub css {
    local $/ = undef;
    return <DATA>;
}

1;
__DATA__

/* 
Basic layout derived from http://www.positioniseverything.net/articles/pie-maker/pagemaker_form.php.
I've changed many so things that I won't put a full copyright notice. However all hacks (and comments!) are far beyond my knowledge and this deserves full credits:

Original copyright notice:
Parts of these notes are
(c) Big John @ www.positioniseverything.net and (c) Paul O'Brien @ www.pmob.co.uk, all of whom contributed significantly to the design of
the css and html code.

Reworked for TWiki: (c) Arthur Clemens @ visiblearea.com
*/

html, body {
	margin:0; /*** Do NOT set anything other than a left margin for the page
as this will break the design ***/
	padding:0;
	border:0;
/* \*/
	height:100%;
/* Last height declaration hidden from Mac IE 5.x */
}
body {
	background:#fff;
	min-width:100%; /*** This is needed for moz. Otherwise, the header and patternBottomBar will
slide off the left side of the page if the screen width is narrower than the design.
Not seen by IE. Left Col + Right Col + Center Col + Both Inner Borders + Both Outer Borders ***/
	text-align:center; /*** IE/Win (not IE/MAC) alignment of page ***/
}
.clear {
	clear:both;
	/*** these next attributes are designed to keep the div
	height to 0 pixels high, critical for Safari and Netscape 7 ***/
	height:0px;
	overflow:hidden;
	line-height:1%;
	font-size:0px;
}

#patternWrapper {
	height:100%; /*** moz uses this to make full height design. As this #patternWrapper is inside the #patternPage which is 100% height, moz will not inherit heights further into the design inside this container, which you should be able to do with use of the min-height style. Instead, Mozilla ignores the height:100% or min-height:100% from this point inwards to the center of the design - a nasty bug.
If you change this to height:100% moz won't expand the design if content grows.
Aaaghhh. I pulled my hair out over this for days. ***/
/* \*/
	height:100%;
/* Last height declaration hidden from Mac IE 5.x */
/*** Fixes height for non moz browsers, to full height ***/
}
#patternWrapp\65	r{ /*** for Opera and Moz (and some others will see it, but NOT Safari) ***/
	height:auto; /*** For moz to stop it fixing height to 100% ***/
}
/* \*/
* html #patternWrapper{
	height:100%;
}

#patternPage {
	margin-left:auto; /*** Mozilla/Opera/Mac IE 5.x alignment of page ***/
	margin-right:auto; /*** Mozilla/Opera/Mac IE 5.x alignment of page ***/
	text-align:left; /*** IE Win re-alignment of page if page is centered ***/
	position:relative;
	width:100%; /*** Needed for Moz/Opera to keep page from sliding to left side of
page when it calculates auto margins above. Can't use min-width. Note that putting
width in #patternPage shows it to IE and causes problems, so IE needs a hack
to remove this width. Left Col + Right Col + Center Col + Both Inner Border + Both Outer Borders ***/
/* \*/

/* Last height declaration hidden from Mac IE 5.x */
/*** Needed for Moz to give full height design if page content is
too small to fill the page ***/
}
/* Last style with height declaration hidden from Mac IE 5.x */
/*** Fixes height for IE, back to full height,
from esc tab hack moz min-height solution ***/
#patternOuter {
	z-index:1; /*** Critical value for Moz/Opera Background Column colors fudge to work ***/
	position:relative; /*** IE needs this or the contents won't show outside the parent container. ***/

	height:100%;
/* Last height declaration hidden from Mac IE 5.x */
/*** Needed for full height inner borders in Win IE ***/
}

#patternFloatWrap {
	width:100%;
	float:left;
	display:inline;
}

#patternLeftBar {
	/* Left bar width is defined in viewleftbar.pattern.tmpl */
	float:left;
	display:inline;
	overflow:hidden;
}
#patternLeftBarContents {
	left:-1px;
	position:relative;
	/* for margins and paddings use style.css */
}
#patternMain {
	width:100%;
	float:right;
	display:inline;
}
#patternTopBar {
	/* Top bar height is defined in viewtopbar.pattern.tmpl */
	z-index:1; /*** Critical value for Moz/Opera Background Column colors fudge to work ***/
	position:absolute;
	top:0px;
	width:100%;
}
#patternTopBarContents {
	height:1%; /* or Win IE won't display a background */
	/* for margins/paddings use style.css */
}
#patternBottomBar {
	z-index:1; /* Critical value for Moz/Opera Background Column colors fudge to work */
	clear:both;
	width:100%;
}

/* Pages that are not view */

.patternNoViewPage #patternOuter {
	/* no left bar, margin at both sides */
	margin-left:4%;
	margin-right:4%;
}

/* edit.pattern.tmpl */

.patternEditPage #patternOuter,
.patternPreviewPage #patternOuter {
	margin-left:0;
	margin-right:0;
}

.twikiLeft {
	float:left;
	position:relative;
}
.twikiRight {
	position:relative;
	float:right;
	display:inline;
	margin:0;
}
.twikiClear {
	/* to clean up floats */
	margin:0;
	padding:0;
	height:0;
	line-height:0px;
	clear:both;
	display:block;
}
.twikiHidden {
	display:none;
}


/*	-----------------------------------------------------------
	STYLE
	Appearance: margins, padding, fonts, borders
	-----------------------------------------------------------	*/
	

/*	----------------------------------------------------------------------------
	CONSTANTS
	
	Sizes
	----------------------------------------
	S1 line-height											1.4em
	S2 somewhat smaller font size							94%
	S3 small font size, twikiSmall							font-size:86%; line-height:110%;
	S4 horizontal bar padding (h2, patternTop)				5px
	S5 form and attachment padding							20px
	S6 left margin left bar									1em

	------------------------------------------------------------------------- */

/* GENERAL HTML ELEMENTS */

html body {
	font-size:104%; /* to change the site's font size, change #patternPage below */
	voice-family:"\"}\""; 
	voice-family:inherit;
	font-size:small;
}
html>body { /* Mozilla */
	font-size:small;	
}
p {
	margin:1em 0 0 0;
}
table {
	border-collapse:separate;
}
th {
	line-height:1.15em;
}
strong, b {
	font-weight:bold;
}
hr {
	height:1px;
	border:none;
}

/* put overflow pre in a scroll area */
pre {
    width:100%;
    margin:0; /* Win IE tries to make this bigger otherwise */
}
html>body pre { /* hide from IE */
	/*\*/ overflow:auto !important; /* */ overflow:scroll; width:auto; /* for Mac Safari */
}
/* IE behavior for pre is defined in twiki.pattern.tmpl in conditional comment */
ol, ul {
	margin-top:0;
}
ol li, ul li {
	line-height:1.4em; /*S1*/
}
	
/* Text */
h1, h2, h3, h4, h5, h6 {
	line-height:104%;
	padding:0;
	margin:1em 0 .1em 0;
	font-weight:normal;
}
h1 {
	margin:0 0 .5em 0;
}
h1 { font-size:210%; }
h2 { font-size:160%; }
h3 { font-size:135%; font-weight:bold; }
h4 { font-size:122%; font-weight:bold; }
h5 { font-size:110%; font-weight:bold; }
h6 { font-size:95%; font-weight:bold; }
h2, h3, h4, h5, h6 {
	display:block;
	/* give header a background color for easy scanning:*/
	padding:.1em 5px;
	margin:1em -5px .35em -5px;
	border-width:0 0 1px 0;
	border-style:solid;
	height:auto;	
}
h1.patternTemplateTitle {
	font-size:175%;
	text-align:center;
}
h2.patternTemplateTitle {
	text-align:center;
}
/* Links */
/* somehow the twikiNewLink style have to be before the general link styles */
.twikiNewLink {
	border-width:0 0 1px 0;
	border-style:solid;
}
.twikiNewLink a {
	text-decoration:none;
	margin-left:1px;
}
.twikiNewLink a sup {
	text-align:center;
	padding:0 2px;
	vertical-align:baseline;
	font-size:100%;
	text-decoration:none;
}
.twikiNewLink a:link sup,
.twikiNewLink a:visited sup {
	border-width:1px;
	border-style:solid;
	text-decoration:none;
}
.twikiNewLink a:hover sup {
	text-decoration:none;
}

:link:focus,
:visited:focus,
:link,
:visited,
:link:active,
:visited:active {
	text-decoration:underline;
}
:link:hover,
:visited:hover {
	text-decoration:none;
}
img {
	vertical-align:text-bottom;
	border:0;
}

/* Form elements */
form { 
	display:inline;
	margin:0;
	padding:0;
}
textarea,
input,
select {
	vertical-align:middle;
	border-width:1px;
	border-style:solid;
}
textarea {
	padding:1px;
}
input,
select option {
	padding:1px;
}
.twikiSubmit,
.twikiButton,
.twikiCheckbox {
	border-width:1px;
	border-style:solid;
	padding:.15em .25em;
	font-size:94%;
	font-weight:bold;
	vertical-align:middle;
}
.twikiCheckbox,
.twikiRadioButton {
	margin:0 .3em 0 0;
	border:0;
}
.twikiInputField {
	border-width:1px;
	border-style:solid;
	padding:.15em .25em;
	font-size:94%; /*S2*/
}
.patternFormButton {
	border:0;
	margin:0 0 0 2px;
}
textarea {
	font-size:100%;
}
blockquote {
	border-width:1px;
	border-style:solid;
	padding:.5em 1em;
}

/* LAYOUT ELEMENTS */
/* for specific layout sub-elements see further down */

#patternPage {
	font-family:arial, "Lucida Grande", verdana, sans-serif;
	line-height:1.4em; /*S1*/
	/* change font size here */
	font-size:105%;
}
#patternTopBar {
	border-width:0 0 1px 0;
	border-style:solid;
	overflow:hidden;
}
#patternTopBarContents {
	padding:0 1.5em 0 1em;
}
#patternBottomBar {
	border-width:1px 0 0 0;
	border-style:solid;
}
#patternBottomBarContents {
	padding:1em;
	font-size:86%; line-height:110%; /*S3*/
	text-align:center;
}
#patternMainContents {
	padding:0 1.5em 3em 3em;
}
#patternLeftBarContents {
	margin:0 1em 1em 1em;
}

/*	-----------------------------------------------------------
	Plugin elements
	-----------------------------------------------------------	*/

/* TagMePlugin */
.tagMePlugin select {
	font-size:.86em; /* use em instead of % for consistent size */
	margin:0 .25em 0 0;
}
.tagMePlugin input { 
	border:0px;
}

/* EditTablePlugin */
.editTable .twikiTable {
	margin:0 0 2px 0;
}
.editTableInput,
.editTableTextarea {
	font-family:monospace;
}
.editTableEditImageButton {
	border:none;
}

/* TablePlugin */
.twikiTable {
	border-style:solid;
	border-width:1px;
}
.twikiTable td {
	padding:.25em .5em;
	border-style:solid;
	border-width:0 0 1px 0;
}
.twikiTable th {
	border-style:solid;
	border-width:0 0 0 1px;
	padding:.4em .5em;
}
.twikiTable th.twikiFirstCol {
	border-left-width:0px;
}

.twikiEditForm {
	margin:0 0 .5em 0;
}


/* TipsContrib */
.tipsOfTheDayContents .tipsOfTheDayTitle {
	font-weight:bold;
}
.patternTopic .tipsOfTheDayHeader {
	display:block;
	padding:3px 5px;
}
.patternTopic .tipsOfTheDayText {
	padding:0 5px 5px 5px;
}
.patternTopic .tipsOfTheDayText a:link,
.patternTopic .tipsOfTheDayText a:visited {
	text-decoration:none;
}
/* TipsContrib - in left bar */
#patternLeftBar .tipsOfTheDayHeader img {
	/* hide lamp icon */
	display:none;
}
#patternLeftBar .tipsOfTheDayContents {
	padding:.25em .25em .5em .25em;
	height:1%; /* or Win IE won't display a background */
	overflow:hidden;
}
#patternLeftBar .tipsOfTheDayHeader {
	display:block;
	font-weight:normal;
}

/* TwistyContrib */
.twistyTrigger a:link,
.twistyTrigger a:visited {
	text-decoration:none;
}
.twistyTrigger a:link .twikiLinkLabel,
.twistyTrigger a:visited .twikiLinkLabel {
	text-decoration:none;
}

/*	-----------------------------------------------------------
	TWiki styles
	-----------------------------------------------------------	*/

.twikiLast,
.patternTopic .twikiLast {
	border-bottom:0px;
}
#twikiLogin {
	width:40em;
	margin:0 auto;
	text-align:center;
}
#twikiLogin .twikiFormSteps {
	border-width:5px;
}
.twikiAttachments,
.twikiForm {
	margin:1em 0;
	padding:1px; /* fixes disappearing borders because of overflow:auto; in twikiForm */
}
.twikiTable h2, .twikiFormTable h2,
.twikiTable h3, .twikiFormTable h3,
.twikiTable h4, .twikiFormTable h4,
.twikiTable h5, .twikiFormTable h5,
.twikiTable h6, .twikiFormTable h6 {
	border:0;
	margin-top:0;
	margin-bottom:0;
}
.twikiFormTable th {
	font-weight:normal;
}
.patternEditPage .twikiFormTable td,
.patternEditPage .twikiFormTable th {
	padding:.8em .5em;
	border-style:solid;
	border-width:0 0 1px 0;
	vertical-align:middle;
}

.patternContent .twikiAttachments,
.patternContent .twikiForm {
	/* form or attachment table inside topic area */
	font-size:94%; /*S2*/
	padding:1em 20px; /*S5*/ /* top:use less padding for the toggle link; bottom:use less space in case the table is folded in  */
	border-width:1px 0 0 0;
	border-style:solid;
	margin:0;
}
.twikiAttachments table,
table.twikiFormTable {
	margin:5px 0;
	border-collapse:collapse;
	padding:0px;
	border-spacing:0px;
	empty-cells:show;
	border-style:solid;
	border-width:1px;
}
.twikiAttachments table {
	line-height:1.4em; /*S1*/
	width:auto;
	voice-family:"\"}\""; /* hide the following for Explorer 5.x */
	voice-family:inherit;
	width:100%;
}
.twikiAttachments td, 
.twikiAttachments th {
	border-style:solid;
	border-width:1px;
}
.twikiAttachments th,
table.twikiFormTable th.twikiFormTableHRow {
	padding:3px 6px;
	height:2.5em;
	vertical-align:middle;
}
table.twikiFormTable th.twikiFormTableHRow {
	text-align:center;
}
.twikiAttachments a:link,
.twikiAttachments a:visited {
	text-decoration:none;
}
.twikiAttachments td,
table.twikiFormTable td {
	padding:3px 6px;
	height:1.4em; /*S1*/
	text-align:left;
	vertical-align:top;
}
.twikiAttachments td {
	/* don't show column lines in attachment listing */
	border-width:0 0 1px 0;
}
.twikiAttachments th.twikiFirstCol {
	border-width:1px;
}
.twikiAttachments th.twikiFirstCol,
.twikiAttachments td.twikiFirstCol {
	/* make more width for the icon column */
	width:26px;
	text-align:center;
}
.twikiAttachments caption {
	display:none;
}
table.twikiFormTable th.twikiFormTableHRow a:link,
table.twikiFormTable th.twikiFormTableHRow a:visited {
	text-decoration:none;
}

.twikiFormSteps {
	text-align:left;
	padding:.25em 0 0 0;
	border-width:1px 0;
	border-style:solid;
}
.twikiFormStep {
	line-height:140%;
	padding:1em 20px; /*S5*/
	border-width:0 0 1px 0;
	border-style:solid;
}
.twikiFormStep h3,
.twikiFormStep h4 {
	font-size:115%;
	border:none;
	margin:0;
	padding:0;
}
.twikiFormStep h3 {
	font-weight:bold;
}
.twikiFormStep h4 {
	font-weight:normal;
}
.twikiFormStep p {
	margin:.3em 0;
}

.twikiToc {
	margin:1em 0;
	padding:.3em 0 .6em 0;
}
.twikiToc ul {
	list-style:none;
	padding:0 0 0 .5em;
	margin:0;
}
.twikiToc li {
	margin-left:1em;
	padding-left:1em;
	background-repeat:no-repeat;
	background-position:0 .5em;
}
.twikiToc .twikiTocTitle {
	margin:0;
	padding:0;
	font-weight:bold;
}

.twikiSmall {
	font-size:86%; line-height:110%; /*S3*/
}
.twikiSmallish {
	font-size:94%; /*S2*/
}
.twikiNew { }
.twikiSummary {
	font-size:86%; line-height:110%; /*S3*/
}
.twikiEmulatedLink {
	text-decoration:underline;
}
.twikiPageForm table {
	border-width:1px;
	border-style:solid;
}
.twikiPageForm table {
	width:100%;
	margin:0 0 2em 0;
}
.twikiPageForm th,
.twikiPageForm td {
	border:0;
	padding:.15em 1em;
}
.twikiPageForm td {}
.twikiPageForm td.first {
	padding-top:1em;
}
.twikiBroadcastMessage {
	padding:.25em .5em;
	margin:0 0 1em 0;
}
.twikiHelp {
	padding:1em;
	margin:0 0 -1px 0;
	border-width:1px 0;
	border-style:solid;
}
.twikiHelp ul,
.twikiHelp li {
	margin:0;
}
.twikiHelp ul {
	padding-left:2em;
}
.twikiAccessKey {
	text-decoration:none;
	border-width:0 0 1px 0;
	border-style:solid;
}
a:hover .twikiAccessKey {
	text-decoration:none;
	border:none;
}
.twikiWebIndent {
	margin:0 0 0 1em;
}
a.twikiLinkInHeaderRight {
	float:right;
	display:block;
	margin:0 0 0 5px;
}
.twikiLinkLabel {}

/*	-----------------------------------------------------------
	Pattern skin specific elements
	-----------------------------------------------------------	*/

.patternTopic {
	margin:1em 0 2em 0;
}
.patternTopic .patternBlockquote {
	margin:1em 0 1em 5em;
}

#patternLeftBarContents {
	font-size:94%; /*S2*/
	padding:0 0 .5em 0;
}
#patternLeftBarContents a img {
	margin:1px 0 0 0;
}
#patternLeftBarContents a:link,
#patternLeftBarContents a:visited {
	text-decoration:none;
}
#patternLeftBarContents ul {
	padding:0;
	margin:.5em 0 1em 0;
	list-style:none;
}
#patternLeftBarContents li {
	width:100%;
	margin:0 1.1em 0 0;
	overflow:hidden;
}
#patternLeftBarContents h2 {
	border:none;
	background-color:transparent;
}
#patternLeftBarContents .patternWebIndicator {
	margin:0 -1em; /*S6*/
	padding:.55em 1em; /*S6*/
	line-height:1.4em;
	text-align:center;
}
#patternLeftBarContents .patternWebIndicator a:link,
#patternLeftBarContents .patternWebIndicator a:visited {
	text-decoration:none;
}
#patternLeftBarContents .patternLeftBarPersonal {
	margin:0 -1em; /*S6*/
	padding:.55em 1em; /*S6*/
	width:100%;
	border-width:0 0 1px 0;
	border-style:solid;
}
#patternLeftBarContents .patternLeftBarPersonal ul {
	margin:0;
	padding:0;
}
#patternLeftBarContents .patternLeftBarPersonal li {
	padding-left:1em;
	background-repeat:no-repeat;
}
#patternLeftBarContents .patternLeftBarPersonal a:hover {
	text-decoration:none;
}


.patternTop {
	font-size:94%; /*S2*/
}
/* Button tool bar */
.patternToolBar {
	margin:.4em 0 0 0;
	padding:0 .5em 0 0;
	height:1%; /* for Win IE */
}
.patternToolBarButtons {
	float:right;
}
.patternToolBarButtons .twikiSeparator {
	display:none;
}
.patternToolBar .patternButton {
	float:left;
}
.patternToolBar .patternButton s,
.patternToolBar .patternButton strike,
.patternToolBar .patternButton a:link,
.patternToolBar .patternButton a:visited {
	display:block;
	margin:0 0 -1px 4px;
	border-width:1px;
	border-style:solid;
	/* relative + z-index removed due to buggy Win/IE redrawing problems */
	/*
	position:relative;
	z-index:0;
	*/
	padding:.15em .45em;
}
.patternToolBar .patternButton a:link,
.patternToolBar .patternButton a:visited {
	text-decoration:none;
}
.patternToolBar .patternButton s,
.patternToolBar .patternButton strike {
	text-decoration:none;
}
.patternToolBar .patternButton a:hover {
	text-decoration:none;
	/*z-index:3;*/
}
.patternToolBarBottom {
	position:relative;
	border-width:1px 0 0 0;
	border-style:solid;
	z-index:2;
	clear:both;
}
.patternMetaMenu input,
.patternMetaMenu select,
.patternMetaMenu select option {
	font-size:.86em; /* use em instead of % for consistent size */
	margin:0;
	width:8em;
}
.patternMetaMenu select option {
	padding:1px 0 0 0;
}
.patternMetaMenu ul {
    padding:0;
    margin:0;
   	list-style:none;
}
.patternMetaMenu ul li {
    padding:0 .1em 0 .1em;
	display:inline;
}

/* breadcrumb */
.patternHomePath {
	font-size:94%; /*S2*/
	margin:.3em 0;
}
.patternHomePath a:link,
.patternHomePath a:visited {
	text-decoration:none;
}
.patternRevInfo {
	margin:0 0 0 .15em;
	font-size:94%;
}
.patternTopicActions {
	border-width:0 0 1px 0;
	border-style:solid;
}
.patternTopicAction {
	line-height:1.5em;
	padding:.4em 20px; /*S5*/
	border-width:1px 0 0 0;
	border-style:solid;
}
.patternViewPage .patternTopicAction {
	font-size:94%; /*S2*/
}
.patternActionButtons a:link,
.patternActionButtons a:visited {
	padding:1px 1px 2px 1px;
}
.patternTopicAction .patternActionButtons a:link,
.patternTopicAction .patternActionButtons a:visited {
	text-decoration:none;
}
.patternTopicAction .patternSaveOptions {
	margin-bottom:.5em;
}
.patternTopicAction .patternSaveOptions .patternSaveOptionsContents {
	padding:.2em 0;
}
.patternMoved {
	font-size:94%; /*S2*/
	margin:1em 0;
}
.patternMoved i,
.patternMoved em {
	font-style:normal;
}

/* WebSearch, WebSearchAdvanced */
table#twikiSearchTable {
	background:none;
	border-bottom:0;
} 
table#twikiSearchTable th,
table#twikiSearchTable td {
	padding:.5em;
	border-width:0 0 1px 0;
	border-style:solid;
} 
table#twikiSearchTable th {
	width:20%;
	text-align:right;
}
table#twikiSearchTable td {
	width:80%;
}
table#twikiSearchTable td.first {
	padding:1em;
}

/*	-----------------------------------------------------------
	Search results
	styles and overridden styles used in search.pattern.tmpl
	-----------------------------------------------------------	*/

.patternSearchResults {
	/* no longer used in search.pattern.tmpl, but remains in rename templates */
	margin:0 0 1em 0;
}
.patternSearchResults blockquote {
	margin:1em 0 1em 5em;
}
h3.patternSearchResultsHeader,
h4.patternSearchResultsHeader {
	display:block;
	border-width:0 0 1px 0;
	border-style:solid;
	height:1%; /* or WIN/IE wont draw the backgound */
	font-weight:bold;
}
.patternSearchResults h3 {
	font-size:115%; /* same as twikiFormStep */
	margin:0;
	padding:.5em 20px;
	font-weight:bold;
}
h4.patternSearchResultsHeader {
	font-size:100%;
	padding-top:.3em;
	padding-bottom:.3em;
	font-weight:normal;
}
.patternSearchResult .twikiTopRow {
	padding-top:.2em;
}
.patternSearchResult .twikiBottomRow {
	padding-bottom:.25em;
	border-width:0 0 1px 0;
	border-style:solid;
}
.patternSearchResult .twikiAlert {
	font-weight:bold;
}
.patternSearchResult .twikiSummary .twikiAlert {
	font-weight:normal;
}
.patternSearchResult .twikiNew {
	border-width:1px;
	border-style:solid;
	font-size:85%; /*S3*/
	padding:0 1px;
	font-weight:bold;
}
.patternSearchResults .twikiHelp {
	display:block;
	width:auto;
	padding:.1em 5px;
	margin:1em -5px .35em -5px;
}
.patternSearchResult .twikiSRAuthor {
	width:15%;
	text-align:left;
}
.patternSearchResult .twikiSRRev {
	width:30%;
	text-align:left;
}
.patternSearchResultCount {
	margin:1em 0 3em 0;
}
.patternSearched {
}
.patternSaveHelp {
	line-height:1.5em;
	padding:.5em 20px; /*S5*/
}

/* Search results in book view format */

.patternBookView {
	border-width:0 0 2px 2px;
	border-style:solid;
	/* border color in cssdynamic.pattern.tmpl */
	margin:.5em 0 1.5em -5px;
	padding:0 0 0 5px;
}
.patternBookView .twikiTopRow {
	padding:.25em 5px .15em 5px; /*S4*/
	margin:1em -5px .15em -5px; /*S4*/
}
.patternBookView .twikiBottomRow {
	font-size:100%;
	padding:1em 0 1em 0;
	width:auto;
	border:none;
}

/* pages that are not view */

.patternNoViewPage #patternMainContents {
	padding-top:1.5em;
}


/* oopsmore.pattern.tmpl */

table.patternDiffOptions {
	margin:.5em 0;
	border:none;
}
table.patternDiffOptions td {
	border:none;
	text-align:center;
}
table.patternDiffOptions img {
	padding:0 10px;
	border-width:1px;
	border-style:solid;
}
table.patternDiffOptions input {
	border:0;
}

/* edit.pattern.tmpl */

.patternEditPage .twikiForm h1,
.patternEditPage .twikiForm h2,
.patternEditPage .twikiForm h3 {
	/* same as twikiFormStep */
	font-size:120%;
	font-weight:bold;
}	
.twikiEditboxStyleMono {
	font-family:"Courier New", courier, monaco, monospace;
}
.twikiEditboxStyleProportional {
	font-family:"Lucida Grande", verdana, arial, sans-serif;
}
.twikiChangeFormButtonHolder {
	margin:.5em 0;
	float:right;
}
.twikiChangeFormButton .twikiButton,
.twikiChangeFormButtonHolder .twikiButton {
	padding:0;
	margin:0;
	border:none;
	text-decoration:underline;
	font-weight:normal;
}
.patternFormHolder { /* constrains the textarea */
	width:100%;
}
.patternSigLine {
	margin:.25em 0 .5em 0;
	padding:0 .5em 0 0;
}
.patternEditPage .patternTopicActions {
	margin:1.5em 0 0 0;
}

/* preview.pattern.tmpl */

.patternPreviewArea {
	border-width:1px;
	border-style:solid;
	margin:0 -0.5em 2em -0.5em;
	padding:.5em;
}

/* rename.pattern.tmpl */

.patternRenamePage .patternTopicAction {
	margin-top:-1px;
}

/* attach.pattern.tmpl */

.patternAttachPage .twikiAttachments table {
	width:auto;
}
.patternAttachPage .patternTopicAction {
	margin-top:-1px;
}
.patternAttachPage .twikiAttachments {
	margin-top:0;
}
.patternAttachForm {
	margin:0 0 3.5em 0;
}
.patternMoveAttachment {
	margin:.5em 0 0 0;
	text-align:right;
}

/* rdiff.pattern.tmpl */

.patternDiff {
	/* same as patternBookView */
	border-width:0 0 2px 2px;
	border-style:solid;
	margin:.5em 0 1.5em -5px;
	padding:0 0 0 5px;
}
.patternDiffPage .patternRevInfo ul {
	padding:0;
	margin:2em 0 0 0;
	list-style:none;
}
.patternDiffPage .twikiDiffTable {
	margin:2em 0;
}
.patternDiffPage .twikiDiffTable th,
.patternDiffPage .twikiDiffTable td {
	padding:0 .2em 0 .3em;
}
tr.twikiDiffDebug td {
	border-width:1px;
	border-style:solid;
}
.patternDiffPage td.twikiDiffDebugLeft {
	border-bottom:none;
}
.twikiDiffLineNumberHeader {
	padding:.3em 0;
}


/* PatternSkin colors */
/* Generated by AttachContentPlugin from TWiki.PatternSkinColorSettings */

/* LAYOUT ELEMENTS */

#patternTopBar {
	background-color:#fff;
	border-color:#ccc;
}
#patternMain { /* don't set a background here; use patternOuter */ }
#patternOuter {
	background-color:#fff; /* Sets background of center col */
	border-color:#ccc;
}
#patternLeftBar, #patternLeftBarContents { /* don't set a background here; use patternWrapper */ }
#patternWrapper {
	background-color:#f6fafd;
}
#patternBottomBar {
	background-color:#fff;
	border-color:#ccc;
}
#patternBottomBarContents,
#patternBottomBarContents a:link,
#patternBottomBarContents a:visited {
	color:#8E9195;
}
#patternBottomBarContents a:hover {
	color:#FBF7E8;
}

/* GENERAL HTML ELEMENTS */

html body {
	background-color:#fff;
	color:#000;
}
/* be kind to netscape 4 that doesn't understand inheritance */
body, p, li, ul, ol, dl, dt, dd, acronym, h1, h2, h3, h4, h5, h6 {
	background-color:transparent;
}
hr {
	color:#ccc;
	background-color:#ccc;
}
pre, code, tt {
	color:#7A4707;
}
blockquote {
	border-color:#E2DCC8;
	background-color:#f0f6f9;
}
h1, h2, h3, h4, h5, h6 {
	color:#a00;
}
h1 a:link,
h1 a:visited {
	color:#a00;
}
h1 a:hover {
	color:#FBF7E8;
}
h2 {
	background-color:#FDFAF3;
	border-color:#E2DCC8;
}
h3, h4, h5, h6 {
	border-color:#E9E4D2;
}
/* to override old Render.pm coded font color style */
.twikiNewLink font {
	color:inherit;
}
.twikiNewLink a:link sup,
.twikiNewLink a:visited sup {
	color:#666;
	border-color:#ccc;
}
.twikiNewLink a:hover sup {
	background-color:#D6000F;
	color:#FBF7E8;
	border-color:#D6000F;
}
.twikiNewLink {
	border-color:#ccc;
}
:link:focus,
:visited:focus,
:link,
:visited,
:link:active,
:visited:active {
	color:#06c;
	background-color:transparent;
}
:link:hover,
:visited:hover {
	color:#FBF7E8;
	background-color:#D6000F;
}
:link:hover img,
:visited:hover img {
	background-color:transparent;
}
/* fix for hover over transparent logo: */
#patternTopBar :link:hover img,
#patternTopBar :visited:hover img {
	background:#fff;
}
.patternTopic a:visited {
	color:#666;
}
.patternTopic a:hover {
	color:#FBF7E8;
}

/* Form elements */

textarea,
input,
select {
	border-color:#aaa;
	color:#000;
	background-color:#fff;
}
.twikiSubmit,
.twikiButton {
	border-color:#ddd #aaa #aaa #ddd;
	color:#333;
	background-color:#fff;
}
.twikiSubmit:active,
.twikiButton:active {
	border-color:#999 #ccc #ccc #999;
	color:#000;
}
.twikiSubmitDisabled,
.twikiSubmitDisabled:active {
	border-color:#e0e0e0;
	color:#ccc;
	background-color:#f5f5f5;
}
.twikiInputField,
.twikiSelect {
	border-color:#aaa #ddd #ddd #aaa;
	color:#000;
	background-color:#fff;
}
.twikiInputFieldDisabled {
	color:#666;
}

/*	-----------------------------------------------------------
	Plugin elements
	-----------------------------------------------------------	*/

/* TablePlugin */
.twikiTable,
.twikiTable td {
	border-color:#ccc;
}
.twikiTable th {
	border-color:#ccc #fff;
}
.twikiTable th a:link,
.twikiTable th a:visited,
.twikiTable th a font {
	color:#fff;
}
.twikiTable th a:hover,
.twikiTable th a:hover font {
	color:#fff;
	background-color:#D6000F;
}

/* TwistyContrib */
.twistyPlaceholder {
	color:#8E9195;
}
a:hover.twistyTrigger {
	color:#FBF7E8;
}

/* TipsContrib */
.tipsOfTheDay {
	background-color:#f8fbfc;
}
.patternTopic .tipsOfTheDayHeader {
	color:#333;
}
/* TipsContrib - in left bar */
#patternLeftBar .tipsOfTheDay a:link,
#patternLeftBar .tipsOfTheDay a:visited {
	color:#a00;
}
#patternLeftBar .tipsOfTheDay a:hover {
	color:#FBF7E8;
}

/* RevCommentPlugin */
.revComment .patternTopicAction {
	background-color:#FEFCF6;
}

/*	-----------------------------------------------------------
	TWiki styles
	-----------------------------------------------------------	*/

.twikiGrayText {
	color:#8E9195;
}
.twikiGrayText a:link,
.twikiGrayText a:visited {
	color:#8E9195;
}
.twikiGrayText a:hover {
	color:#FBF7E8;
}

table.twikiFormTable th.twikiFormTableHRow,
table.twikiFormTable td.twikiFormTableRow {
	color:#666;
}
.twikiEditForm {
	color:#000;
}
.twikiEditForm .twikiFormTable,
.twikiEditForm .twikiFormTable th,
.twikiEditForm .twikiFormTable td {
	border-color:#e2e7eb;
}
/* use a different table background color mix: no odd/even rows, no white background */
.twikiEditForm .twikiFormTable td  {
	background-color:#f7fafc;
}
.twikiEditForm .twikiFormTable th {
	background-color:#edf4f9;
}
.patternContent .twikiAttachments,
.patternContent .twikiForm {
	background-color:#FEFCF6;
	border-color:#E2DCC8;
}
.twikiAttachments table,
table.twikiFormTable {
	border-color:#ccc;
	background-color:#fff;
}
.twikiAttachments table {
	background-color:#fff;
}
.twikiAttachments td, 
.twikiAttachments th {
	border-color:#ccc;
}
.twikiAttachments .twikiTable th font,
table.twikiFormTable th.twikiFormTableHRow font {
	color:#06c;
}

.twikiFormSteps {
	background-color:#f0f6f9;
	border-color:#E2DCC8;
}
.twikiFormStep {
	border-color:#E2DCC8;
}
.twikiFormStep h3,
.twikiFormStep h4 {
	background-color:transparent;
}
.twikiToc .twikiTocTitle {
	color:#666;
}
.twikiBroadcastMessage {
	background-color:yellow;
}
.twikiBroadcastMessage b,
.twikiBroadcastMessage strong {
	color:#f00;
}
.twikiAlert,
.twikiAlert code {
	color:#f00;
}
.twikiEmulatedLink {
	color:#06c;
}
.twikiPageForm table {
	border-color:#ccc;
	background:#fff;
}
.twikiPageForm hr {
	border-color:#ccc;
	background-color:#ccc;
	color:#ccc;
}
.twikiHelp {
	background-color:#f8fbfc;
	border-color:#D5E6F3;
}
.twikiAccessKey {
	color:inherit;
	border-color:#8E9195;
}
a:link .twikiAccessKey,
a:visited .twikiAccessKey,
a:hover .twikiAccessKey {
	color:inherit;
}


/*	-----------------------------------------------------------
	Pattern skin specific elements
	-----------------------------------------------------------	*/
#patternPage {
	background-color:#fff;
}
/* Left bar */
#patternLeftBarContents {
	color:#666;
}
#patternLeftBarContents .patternWebIndicator {
	color:#000;
}
#patternLeftBarContents .patternWebIndicator a:link,
#patternLeftBarContents .patternWebIndicator a:visited {
	color:#000;
}
#patternLeftBarContents .patternWebIndicator a:hover {
	color:#FBF7E8;
}
#patternLeftBarContents hr {
	color:#E2DCC8;
	background-color:#E2DCC8;
}
#patternLeftBarContents a:link,
#patternLeftBarContents a:visited {
	color:#666;
}
#patternLeftBarContents a:hover {
	color:#FBF7E8;
}
#patternLeftBarContents b,
#patternLeftBarContents strong {
	color:#333;
}
#patternLeftBarContents .patternChangeLanguage {
	color:#8E9195;
}
#patternLeftBarContents .patternLeftBarPersonal {
	border-color:#ccc;
}
#patternLeftBarContents .patternLeftBarPersonal a:link,
#patternLeftBarContents .patternLeftBarPersonal a:visited {
	color:#06c;
}
#patternLeftBarContents .patternLeftBarPersonal a:hover {
	color:#FBF7E8;
	background-color:#D6000F;
}
.patternTopicActions {
	border-color:#E2DCC8;
}
.patternTopicAction {
	color:#666;
	border-color:#E2DCC8;
	background-color:#FCF8EC;
}
.patternTopicAction s,
.patternTopicAction strike {
	color:#ccc;
}
.patternTopicAction .twikiSeparator {
	color:#E2DCC8;
}
.patternActionButtons a:link,
.patternActionButtons a:visited {
	color:#D6000F;
}
.patternActionButtons a:hover {
	color:#FBF7E8;
}
.patternTopicAction .twikiAccessKey {
	color:#D6000F;
	border-color:#D6000F;
}
.patternTopicAction label {
	color:#000;
}
.patternHelpCol {
	color:#8E9195;
}
.patternFormFieldDefaultColor {
	/* input fields default text color (no user input) */
	color:#8E9195;
}

.patternToolBar .patternButton s,
.patternToolBar .patternButton strike,
.patternToolBar .patternButton a:link,
.patternToolBar .patternButton a:visited {
	border-color:#E2DCC8;
	background-color:#fff;
}
.patternToolBar .patternButton a:link,
.patternToolBar .patternButton a:visited {
	color:#666;
}
.patternToolBar .patternButton s,
.patternToolBar .patternButton strike {
	color:#ccc;
	border-color:#e0e0e0;
}
.patternToolBar .patternButton a:hover {
	background-color:#D6000F;
	color:#FBF7E8;
	border-color:#D6000F;
}
.patternToolBar .patternButton img {
	background-color:transparent;
}	
.patternToolBarBottom {
	border-color:#E2DCC8;
}
.patternToolBar a:link .twikiAccessKey,
.patternToolBar a:visited .twikiAccessKey {
	color:inherit;
	border-color:#666;
}
.patternToolBar a:hover .twikiAccessKey {
	background-color:transparent;
	color:inherit;
}

.patternRevInfo,
.patternRevInfo a:link,
.patternRevInfo a:visited {
	color:#8E9195;
}
.patternRevInfo a:hover {
	color:#FBF7E8;
}

.patternMoved,
.patternMoved a:link,
.patternMoved a:visited {
	color:#8E9195;
}
.patternMoved a:hover {
	color:#FBF7E8;
}
.patternSaveHelp {
	background-color:#fff;
}

/* WebSearch, WebSearchAdvanced */
table#twikiSearchTable th,
table#twikiSearchTable td {
	background-color:#fff;
	border-color:#ccc;
} 
table#twikiSearchTable th {
	color:#8E9195;
}
table#twikiSearchTable td.first {
	background-color:#FCF8EC;
}

/*	-----------------------------------------------------------
	Search results
	styles and overridden styles used in search.pattern.tmpl
	-----------------------------------------------------------	*/

h3.patternSearchResultsHeader,
h4.patternSearchResultsHeader {
	background-color:#FEFCF6;
	border-color:#ccc;
}
h4.patternSearchResultsHeader {
	color:#000;
}
.patternNoViewPage h4.patternSearchResultsHeader {
	color:#a00;
}
.patternSearchResult .twikiBottomRow {
	border-color:#ccc;
}
.patternSearchResult .twikiAlert {
	color:#f00;
}
.patternSearchResult .twikiSummary .twikiAlert {
	color:#900;
}
.patternSearchResult .twikiNew {
	background-color:#ECFADC;
	border-color:#049804;
	color:#049804;
}
.patternViewPage .patternSearchResultsBegin {
	border-color:#ccc;
}

/* Search results in book view format */

.patternBookView .twikiTopRow {
	background-color:transparent; /* set to WEBBGCOLOR in css.pattern.tmpl */
	color:#666;
}
.patternBookView .twikiBottomRow {
	border-color:#ccc;
}
.patternBookView .patternSearchResultCount {
	color:#8E9195;
}

/* oopsmore.pattern.tmpl */

table.patternDiffOptions img {
	border-color:#ccc;
}

/* edit.pattern.tmpl */

.twikiChangeFormButton .twikiButton,
.twikiChangeFormButtonHolder .twikiButton { /* looks like a link */
	color:#06c;
	background:none;
}
.patternSig input {
	color:#8E9195;
	background-color:#fff;
}

/* preview.pattern.tmpl */

.patternPreviewArea {
	border-color:#f00;
	background-color:#fff;
}

/* rdiff.pattern.tmpl */

.patternDiff {
	border-color:#ccc;
}
.patternDiff h4.patternSearchResultsHeader {
	color:#fff;
	background-color:#345;
}
tr.twikiDiffDebug td {
	border-color:#ccc;
}
.patternDiffPage .twikiDiffTable th {
	background-color:#6b7f93;
}
tr.twikiDiffDebug .twikiDiffChangedText,
tr.twikiDiffDebug .twikiDiffChangedText {
	background:#9f9; /* green - do not change */
}
/* Deleted */
tr.twikiDiffDebug .twikiDiffDeletedMarker,
tr.twikiDiffDebug .twikiDiffDeletedText {
	background-color:#f99; /* red - do not change */
}
/* Added */
tr.twikiDiffDebug .twikiDiffAddedMarker,
tr.twikiDiffDebug .twikiDiffAddedText {
	background-color:#ccf; /* violet - do not change */
}
/* Unchanged */
tr.twikiDiffDebug .twikiDiffUnchangedText {
	color:#8E9195;
}
/* Headers */
.twikiDiffChangedHeader,
.twikiDiffDeletedHeader,
.twikiDiffAddedHeader {
	color:#fff;
	background-color:#345;
}
/* Unchanged */
.twikiDiffUnchangedTextContents { }
.twikiDiffLineNumberHeader {
	background-color:#6b7f93;
}



/*	----------------------------------------------------------------------- */
/* configure styles */
/*	----------------------------------------------------------------------- */

#twikiPassword,
#twikiPasswordChange {
	width:40em;
	margin:1em auto;
}
#twikiPassword .twikiFormSteps,
#twikiPasswordChange .twikiFormSteps {
	border-width:5px;
}
div.foldableBlock h1,
div.foldableBlock h2,
div.foldableBlock h3,
div.foldableBlock h4,
div.foldableBlock h5,
div.foldableBlock h6 {
	border:0;
	margin-top:0;
	margin-bottom:0;
}
ul {
    margin-top:0;
    margin-bottom:0;
}
.logo {
    margin:1em 0 1.5em 0;
}
.formElem {
    background-color:#F3EDE7;
    margin:0.5em 0;
    padding:0.5em 1em;
}
.blockLinkAttribute {
    margin-left:0.35em;
}
.blockLinkAttribute a:link,
.blockLinkAttribute a:visited {
	text-decoration:none;
}
a.blockLink {
    display:block;
    padding:0.25em 1em;
    border-bottom:1px solid #aaa;
    text-decoration:none;
}
a:link.blockLink,
a:visited.blockLink {
    text-decoration:none; 
}
a:link:hover.blockLink {
    text-decoration:none;   
}
a:link.blockLinkOff,
a:visited.blockLinkOff {
    background-color:#F3EDE7;
    color:#333;
    font-weight:normal;
}
a:link.blockLinkOn,
a:visited.blockLinkOn {
    background-color:#b4d5ff;
    color:#333;
    font-weight:bold;
}
a.blockLink:hover {
    background-color:#1559B3;
    color:white;
}
div.explanation {
    background-color:#ECF4FB;
    padding:0.5em 1em;
    margin:0.5em 0;
}
div.specialRemark {
    background-color:#fff;
    border:1px solid #ccc;
    margin:0.5em;
    padding:0.5em 1em;
}
div.options {
    margin:1em 0;
}
div.options div.optionHeader {
    padding:0.25em 1em;
    background-color:#666;
    color:white;
    font-weight:bold;
}
div.options div.optionHeader a {
    color:#bbb;
    text-decoration:underline;
}
div.options div.optionHeader a:link:hover,
div.options div.optionHeader a:visited:hover {
    color:#b4d5ff; /* King's blue */
    background-color:#666;
    text-decoration:underline;
}
div.options .twikiSmall {
    margin-left:0.5em;
    color:#bbb;
}
div.foldableBlock {
    border-bottom:1px solid #ccc;
    border-left:1px solid #ddd;
    border-right:1px solid #ddd;
    height:auto;
    width:auto;
    overflow:auto;
}
.foldableBlockOpen {
    display:block;
}
.foldableBlockClosed {
    display:block;
}
div.foldableBlock td {
    padding:0.5em 1em;
    border-top:1px solid #ccc;
    vertical-align:middle;
    line-height:1.2em;
}
div.foldableBlock td.info {
	border-width:6px;
}
.info {
    color:#666; /*T7*/ /* gray */
    background-color:#f8fbfc;
}
.firstInfo {
    color:#000;
    background-color:#fff;
}

.warn {
    color:#f60; /* orange */
    background-color:#FFE8D9; /* light orange */
    border-bottom:1px solid #f60;
}
a.info,
a.warn,
a.error {
	text-decoration:none;
}
.error {
    color:#f00; /*T9*/ /*red*/
    background-color:#FFD9D9; /* pink */
    border-bottom:1px solid #f00;
}
.mandatory,
.mandatory input {
    color:green;
    background-color:#ECFADC;
    font-weight: bold;
}
.mandatory {
    border-bottom:1px solid green;
}
.mandatory input {
    font-weight:normal;
}
.docdata {
    padding-top: 1ex;
    vertical-align: top;
}
.keydata {
    font-weight: bold;
    background-color:#F0F0F0;
    vertical-align: top;
}
.subHead {
    font-weight: bold;
    font-style: italic;
}
.firstCol {
    width: 30%;
    font-weight: bold;
    vertical-align: top;
}
.secondCol {
}
.hiddenRow {
    display:none;
}
