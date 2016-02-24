/**
HTML utility functions.
*/
twiki.HTML = {

	/**
	Writes HTML to an HTMLElement.
	@param inId : (String) id of element to write to
	@param inHtml : (String) HTML to write
	@return The updated HTMLElement
	*/
	setHtmlOfElementWithId:function(inId, inHtml) {
		var elem = document.getElementById(inId);
		return twiki.HTML.setHtmlOfElement(elem, inHtml);
	},
	
	/**
	Writes HTML to HTMLElement inElement.
	@param inElement : (HTMLElement) element to write to
	@param inHtml : (String) HTML to write
	@return The updated HTMLElement
	*/
	setHtmlOfElement:function(inElement, inHtml) {
		if (!inElement || inHtml == undefined) return null;
		inElement.innerHTML = inHtml;
		return inElement;
	},
	
	/**
	Returns the HTML contents of element with id inId.
	@param inId : (String) id of element to get contents of
	@return HTLM contents string.
	*/
	getHtmlOfElementWithId:function(inId) {
		var elem = document.getElementById(inId);
		return twiki.HTML.getHtmlOfElement(elem);
	},
	
	/**
	Returns the HTML contents of element inElement.
	@param inElement : (HTMLElement) element to get contents of
	@return HTLM contents string.
	*/
	getHtmlOfElement:function(inElement) {
		if (!inElement) return null;
		return inElement.innerHTML;
	},
	
	/**
	Clears the contents of element inId.
	@param inId : (String) id of element to clear the contents of
	@return The cleared HTMLElement.
	*/
	clearElementWithId:function(inId) {
		var elem = document.getElementById(inId);
		return twiki.HTML.clearElement(elem);
	},
	
	/**
	Clears the contents of element inElement.
	@param inElement (HTMLElement) : object to clear
	*/
	clearElement:function(inElement) {
		if (!inElement) return null;
		twiki.HTML.setHtmlOfElement(inElement, "");
		return inElement;
	},
	
	/**
	untested
	*/
	deleteElementWithId:function(inId) {
		var elem = document.getElementById(inId);
		return twiki.HTML.deleteElement(elem);
	},
	
	/**
	untested
	*/
	deleteElement:function(inElement) {
		if (!inElement) return null;
		inElement.parentNode.removeChild(inElement);
		return inElement;
	},
	
	/**
	Inserts a new HTMLElement after an existing element.
	@param inElement : (HTMLElement) (required) the element to insert after
	@param inType : (String) (required) element type of the new HTMLElement: 'p', 'b', 'span', etc
	@param inHtmlContents : (String) (optional) element HTML contents
	@param inAttributes : (Object) (optional) value object with attributes to set to the new element
	@return The new HTMLElement
	@use
	<pre>
	twiki.HTML.insertAfterElement(
    		document.getElementById('title'),
    		'div',
    		'<strong>not published</strong>',
    		{
    			"style":
    				{
    					"backgroundColor":"#f00",
    					"color":"#fff"
    				}
    		}
    	);
    </pre>
	*/
	insertAfterElement:function(inElement, inType, inHtmlContents, inAttributes) {
		if (!inElement || !inType) return null;
		var newElement = twiki.HTML._createElementWithTypeAndContents(
			inType,
			inHtmlContents,
			inAttributes
		);
		if (newElement) {
			inElement.appendChild(newElement);
			return newElement;
		}
		return null;
	},
	
	/**
	Inserts a new HTMLElement after an existing element.
	@param inElement : (HTMLElement) (required) the element to insert after
	@param inType : (String) (required) element type of the new HTMLElement: 'p', 'b', 'span', etc
	@param inHtmlContents : (String) (optional) element HTML contents
	@param inAttributes : (Object) (optional) value object with attributes to set to the new element
	@return The new HTMLElement
	*/
	insertBeforeElement:function(inElement, inType, inHtmlContents, inAttributes) {
		if (!inElement || !inType) return null;
		var newElement = twiki.HTML._createElementWithTypeAndContents(
			inType,
			inHtmlContents,
			inAttributes
		);
		if (newElement) {
			inElement.parentNode.insertBefore(newElement, inElement);
			return newElement;
		}
		return null;
	},
	
	/**
	Replaces an existing HTMLElement with a new element.
	@param inElement : (HTMLElement) (required) the existing element to replace
	@param inType : (String) (required) element type of the new HTMLElement: 'p', 'b', 'span', etc
	@param inHtmlContents : (String) (optional) element HTML contents
	@param inAttributes : (Object) (optional) value object with attributes to set to the new element
	@return The new HTMLElement
	*/
	replaceElement:function(inElement, inType, inHtmlContents, inAttributes) {
		if (!inElement || !inType) return null;
		var newElement = twiki.HTML._createElementWithTypeAndContents(
			inType,
			inHtmlContents,
			inAttributes
		);
		if (newElement) {
			inElement.parentNode.replaceChild(newElement, inElement);
			return newElement;
		}
		return null;
	},
	
	/**
	Creates a new HTMLElement. See insertAfterElement, insertBeforeElement and replaceElement.
	@return The new HTMLElement
	@priviliged
	*/
	_createElementWithTypeAndContents:function(inType, inHtmlContents, inAttributes) {
		var newElement = document.createElement(inType);
		if (inHtmlContents != undefined) {
			newElement.innerHTML = inHtmlContents;
		}
		if (inAttributes != undefined) {
			twiki.HTML.setElementAttributes(newElement, inAttributes);
		}
		return newElement;
	},

	/**
	Passes attributes from value object inAttributes to all nodes in NodeList inNodeList.
	@param inNodeList : (NodeList) nodes to set the style of
	@param inAttributes : (Object) value object with element properties, with stringified keys. For example, use "class":"twikiSmall" to set the class. This cannot be a property key written as <code>class</code> because this is a reserved keyword.
	@use
	In this example all NodeList elements get assigend a class and style:
	<pre>
	var elem = document.getElementById("my_div");
	var nodeList = elem.getElementsByTagName('ul')
	var attributes = {
		"class":"twikiSmall twikiGrayText",
    	"style":
    		{
    			"fontSize":"20px",
    			"backgroundColor":"#444",
    			"borderLeft":"5px solid red",
				"margin":"0 0 1em 0"
    		}
    	};
	};
	twiki.HTML.setNodeAttributesInList(nodeList, attributes);
	</pre>
	*/
	setNodeAttributesInList:function (inNodeList, inAttributes) {
		if (!inNodeList) return;
		var i, ilen = inNodeList.length;
		for (i=0; i<ilen; ++i) {
			var elem = inNodeList[i];
			twiki.HTML.setElementAttributes(elem, inAttributes);
		}
	},
	
	/**
	Sets attributes to an HTMLElement.
	@param inElement : (HTMLElement) element to set attributes to
	@param inAttributes : (Object) value object with attributes
	*/
	setElementAttributes:function (inElement, inAttributes) {
		for (var attr in inAttributes) {
			if (attr == "style") {
				var styleObject = inAttributes[attr];
				for (var style in styleObject) {
					inElement.style[style] = styleObject[style];
				}
			} else {
				//inElement.setAttribute(attr, inAttributes[attr]);
				inElement[attr] = inAttributes[attr];
			}
		}
	}
	
};