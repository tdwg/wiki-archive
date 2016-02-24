/**
Checks/unchecks all checkboxes in a form. Assumes that the form is set as pageElem.
*/
function checkAll(theCheck) {
	// find button element index
	var i, j = 0;
	for (i = 0; i < pageElem.length; ++i) {
		if (pageElem.elements[i].name.match("referring_topics")) {
			pageElem.elements[i].checked = theCheck;
		}
	}
}