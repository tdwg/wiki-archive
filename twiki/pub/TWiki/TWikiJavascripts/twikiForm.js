twiki.Form = {

	KEYVALUEPAIR_DELIMITER : ";",
	
	/*
	Original js filename: formdata2querystring.js
	
	Copyright 2005 Matthew Eernisse (mde@fleegix.org)
	
	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at
	
	http://www.apache.org/licenses/LICENSE-2.0
	
	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
	Original code by Matthew Eernisse (mde@fleegix.org), March 2005
	Additional bugfixes by Mark Pruett (mark.pruett@comcast.net), 12th July 2005
	Multi-select added by Craig Anderson (craig@sitepoint.com), 24th August 2006

	Version 1.3
	
	Changes for TWiki:
	Added KEYVALUEPAIR_DELIMITER by Arthur Clemens
	*/
	
	/**
	Serializes the data from all the inputs in a Web form
	into a query-string style string.
	@param inForm : Reference to a DOM node of the form element
	@param inFormatOptions : value object of options for how to format the return string. Supported options:
		  collapseMulti: (Boolean) take values from elements that can return multiple values (multi-select, checkbox groups) and collapse into a single, comma-delimited value (e.g., thisVar=asdf,qwer,zxcv)
	@returns Query-string formatted String of variable-value pairs
	*/
	formData2QueryString:function (inForm, inFormatOptions) {
		if (!inForm) return null;
		var opts = inFormatOptions || {};
		var str = '';
		var formElem;
		var lastElemName = '';
		
		for (i = 0; i < inForm.elements.length; i++) {
			formElem = inForm.elements[i];
			
			switch (formElem.type) {
				// Text fields, hidden form elements
				case 'text':
				case 'hidden':
				case 'password':
				case 'textarea':
				case 'select-one':
					str += formElem.name
						+ '='
						+ encodeURI(formElem.value)
						+ twiki.Form.KEYVALUEPAIR_DELIMITER;
					break;
				
				// Multi-option select
				case 'select-multiple':
					var isSet = false;
					for(var j = 0; j < formElem.options.length; j++) {
						var currOpt = formElem.options[j];
						if(currOpt.selected) {
							if (opts.collapseMulti) {
								if (isSet) {
									str += ','
										+ encodeURI(currOpt.text);
								} else {
									str += formElem.name
										+ '='
										+ encodeURI(currOpt.text);
									isSet = true;
								}
							} else {
								str += formElem.name
									+ '='
									+ encodeURI(currOpt.text)
									+ twiki.Form.KEYVALUEPAIR_DELIMITER;
							}
						}
					}
					if (opts.collapseMulti) {
						str += twiki.Form.KEYVALUEPAIR_DELIMITER;
					}
					break;
				
				// Radio buttons
				case 'radio':
					if (formElem.checked) {
						str += formElem.name
							+ '='
							+ encodeURI(formElem.value)
							+ twiki.Form.KEYVALUEPAIR_DELIMITER;
					}
					break;
				
				// Checkboxes
				case 'checkbox':
					if (formElem.checked) {
						// Collapse multi-select into comma-separated list
						if (opts.collapseMulti && (formElem.name == lastElemName)) {
						// Strip of end ampersand if there is one
						if (str.lastIndexOf('&') == str.length-1) {
							str = str.substr(0, str.length - 1);
						}
						// Append value as comma-delimited string
						str += ','
							+ encodeURI(formElem.value);
						}
						else {
						str += formElem.name
							+ '='
							+ encodeURI(formElem.value);
						}
						str += twiki.Form.KEYVALUEPAIR_DELIMITER;
						lastElemName = formElem.name;
					}
					break;
					
				} // switch
			} // for
		// Remove trailing separator
		str = str.substr(0, str.length - 1);
		return str;
	}
};