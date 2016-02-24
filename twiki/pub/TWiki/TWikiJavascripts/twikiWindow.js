twiki.Window = {
	
	POPUP_WINDOW_WIDTH : 500,
	POPUP_WINDOW_HEIGHT : 480,
	POPUP_ATTRIBUTES : "titlebar=0,resizable,scrollbars",
	
	/**
	Launch a fixed-size help window.
	@param inUrl : (required) URL String of new window
	@param inOptions : (optional) value object with keys:
		web : (String) name of Web
		topic : (String) name of topic; will be window name unless specified in 'name'
		skin : (String) name of skin
		template : (String) name of template
		cover : (String) name of cover
		section : (String) name of section
		name : (String) name of window; may be set if 'topic' has not been set
		width : (String) width of new window; overrides default value POPUP_WINDOW_WIDTH
		height : (String) height of new window; overrides default value POPUP_WINDOW_HEIGHT
		attributes : (String) additional window attributes; overrides default value POPUP_ATTRIBUTES
	@param inAltWindow : (Window) Window where url is loaded into if no pop-up could be created. The original window contents is replaced with the passed url (plus optionally web, topic, skin path)
	@use
	<pre>
	var window = twiki.Window.openPopup(
		"%SCRIPTURL{view}%/",
			{
    			topic:"WebChanges",
    			web:"%TWIKIWEB%"
    		}
    	);
	</pre>
	@return The new Window object.
	*/
	openPopup:function (inUrl, inOptions, inAltWindow) {
		if (!inUrl) return null;
		
		var paramsString = "";
		var name = "";
		var pathString = inUrl;
		var windowAttributes = [];
		
		// set default values, may be overridden below
		var width = twiki.Window.POPUP_WINDOW_WIDTH;
		var height = twiki.Window.POPUP_WINDOW_HEIGHT;
		var attributes = twiki.Window.POPUP_ATTRIBUTES;
		
		if (inOptions) {
			var pathElements = [];
			if (inOptions.web != undefined) pathElements.push(inOptions.web);
			if (inOptions.topic != undefined) {				
				pathElements.push(inOptions.topic);
			}
			pathString += pathElements.join("/");
			
			var params = [];
			if (inOptions.skin != undefined) {
				params.push("skin=" + inOptions.skin);
			}
			if (inOptions.template != undefined) {
				params.push("template=" + inOptions.template);
			}
			if (inOptions.section != undefined) {
				params.push("section=" + inOptions.section);
			}
			if (inOptions.cover != undefined) {
				params.push("cover=" + inOptions.cover);
			}
			paramsString = params.join(";");
			if (paramsString.length > 0) {
				// add query string
				paramsString = "?" + paramsString;
			}			
			if (inOptions.topic != undefined) {
				name = inOptions.topic;
			}
			if (inOptions.name != undefined) {
				name = inOptions.name;
			}
			
			if (inOptions.width != undefined) width = inOptions.width;
			if (inOptions.height != undefined) height = inOptions.height;
			if (inOptions.attributes != undefined) attributes = inOptions.attributes;
		}
		
		windowAttributes.push("width=" + width);
		windowAttributes.push("height=" + height);
		windowAttributes.push(attributes);
		var attributesString = windowAttributes.join(",");
		
		var window = open(pathString + paramsString, name, attributesString);
		if (window) {
			window.focus();
			return window;
		}
		// no window opened
		if (inAltWindow && inAltWindow.document) {
			inAltWindow.document.location.href = pathString;
		}
		return null;
	}
};