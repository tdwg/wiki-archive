TWiki.TwistyPlugin=new function(){
var _1=this;
this._getName=function(_2){
var re=new RegExp("(.*)(hide|show|toggle)","g");
var m=re.exec(_2);
var _5=(m&&m[1])?m[1]:"";
return _5;
};
this._getType=function(_6){
var re=new RegExp("(.*)(hide|show|toggle)","g");
var m=re.exec(_6);
var _9=(m&&m[2])?m[2]:"";
return _9;
};
this._toggleTwisty=function(_a){
if(!_a){
return;
}
_a.state=(_a.state==TWiki.TwistyPlugin.CONTENT_HIDDEN)?TWiki.TwistyPlugin.CONTENT_SHOWN:TWiki.TwistyPlugin.CONTENT_HIDDEN;
_1._update(_a,true);
};
this._update=function(_b,_c){
var _d=_b.show;
var _e=_b.hide;
var _f=_b.toggle;
if(_b.state==TWiki.TwistyPlugin.CONTENT_SHOWN){
addClass(_d,"twistyHidden");
removeClass(_e,"twistyHidden");
removeClass(_f,"twistyHidden");
}else{
removeClass(_d,"twistyHidden");
addClass(_e,"twistyHidden");
addClass(_f,"twistyHidden");
}
if(_c&&_b.saveSetting){
setPref(TWiki.TwistyPlugin.COOKIE_PREFIX+_b.name,_b.state);
}
if(_b.clearSetting){
setPref(TWiki.TwistyPlugin.COOKIE_PREFIX+_b.name,"");
}
};
this._register=function(e){
if(!e){
return;
}
var _11=_1._getName(e.id);
var ref=_1._storage[_11];
if(!ref){
ref=new TWiki.TwistyPlugin.Storage();
}
if(hasClass(e,"twistyRememberSetting")){
ref.saveSetting=true;
}
if(hasClass(e,"twistyForgetSetting")){
ref.clearSetting=true;
}
if(hasClass(e,"twistyStartShow")){
ref.startShown=true;
}
if(hasClass(e,"twistyStartHide")){
ref.startHidden=true;
}
if(hasClass(e,"twistyFirstStartShow")){
ref.firstStartShown=true;
}
if(hasClass(e,"twistyFirstStartHide")){
ref.firstStartHidden=true;
}
ref.name=_11;
var _13=_1._getType(e.id);
ref[_13]=e;
_1._storage[_11]=ref;
switch(_13){
case "show":
case "hide":
e.onclick=function(){
_1._toggleTwisty(ref);
return false;
};
break;
}
return ref;
};
this._storage={};
this._UIbehaviour={".twistyTrigger":function(e){
TWiki.TwistyPlugin.init(e.id);
},".twistyContent":function(e){
TWiki.TwistyPlugin.init(e.id);
},".twistyExpandAll":function(e){
e.onclick=function(){
TWiki.TwistyPlugin.toggleAll(TWiki.TwistyPlugin.CONTENT_SHOWN);
};
},".twistyCollapseAll":function(e){
e.onclick=function(){
TWiki.TwistyPlugin.toggleAll(TWiki.TwistyPlugin.CONTENT_HIDDEN);
};
}};
Behaviour.register(this._UIbehaviour);
};
TWiki.TwistyPlugin.CONTENT_HIDDEN=0;
TWiki.TwistyPlugin.CONTENT_SHOWN=1;
TWiki.TwistyPlugin.COOKIE_PREFIX="TwistyContrib_";
TWiki.TwistyPlugin.prefList;
TWiki.TwistyPlugin.init=function(_18){
var e=document.getElementById(_18);
if(!e){
return;
}
var _1a=this._getName(_18);
var ref=this._storage[_1a];
if(ref&&ref.show&&ref.hide&&ref.toggle){
return ref;
}
ref=this._register(e);
if(hasClass(e,"twistyMakeHidden")){
replaceClass(e,"twistyMakeHidden","twistyHidden");
}
if(hasClass(e,"twistyMakeVisible")){
removeClass(e,"twistyMakeVisible");
}
if(ref.show&&ref.hide&&ref.toggle){
if(TWiki.TwistyPlugin.prefList==null){
TWiki.TwistyPlugin.prefList=getPrefList();
}
var _1c=getPrefValueFromPrefList(TWiki.TwistyPlugin.COOKIE_PREFIX+ref.name,TWiki.TwistyPlugin.prefList);
if(ref.firstStartHidden){
ref.state=TWiki.TwistyPlugin.CONTENT_HIDDEN;
}
if(ref.firstStartShown){
ref.state=TWiki.TwistyPlugin.CONTENT_SHOWN;
}
if(_1c&&_1c=="0"){
ref.state=TWiki.TwistyPlugin.CONTENT_HIDDEN;
}
if(_1c&&_1c=="1"){
ref.state=TWiki.TwistyPlugin.CONTENT_SHOWN;
}
if(ref.startHidden){
ref.state=TWiki.TwistyPlugin.CONTENT_HIDDEN;
}
if(ref.startShown){
ref.state=TWiki.TwistyPlugin.CONTENT_SHOWN;
}
this._update(ref,false);
}
return ref;
};
TWiki.TwistyPlugin.toggleAll=function(_1d){
var i;
for(var i in this._storage){
var e=this._storage[i];
e.state=_1d;
this._update(e,true);
}
};
TWiki.TwistyPlugin.Storage=function(){
this.name;
this.state=TWiki.TwistyPlugin.CONTENT_HIDDEN;
this.hide;
this.show;
this.toggle;
this.saveSetting=false;
this.clearSetting=false;
this.startShown;
this.startHidden;
this.firstStartShown;
this.firstStartHidden;
};
