var Behaviour={list:new Array,register:function(_1){
Behaviour.list.push(_1);
},start:function(){
Behaviour.addLoadEvent(function(){
Behaviour.apply();
});
},apply:function(){
for(h=0;sheet=Behaviour.list[h];h++){
for(selector in sheet){
list=document.getElementsBySelector(selector);
if(!list){
continue;
}
for(i=0;element=list[i];i++){
sheet[selector](element);
}
}
}
},addLoadEvent:function(_2){
var _3=window.onload;
if(typeof window.onload!="function"){
window.onload=_2;
}else{
window.onload=function(){
_3();
_2();
};
}
}};
Behaviour.start();
function getAllChildren(e){
return e.all?e.all:e.getElementsByTagName("*");
}
document.getElementsBySelector=function(_5){
if(!document.getElementsByTagName){
return new Array();
}
var _6=_5.split(" ");
var _7=new Array(document);
for(var i=0;i<_6.length;i++){
token=_6[i].replace(/^\s+/,"").replace(/\s+$/,"");
if(token.indexOf("#")>-1){
var _9=token.split("#");
var _a=_9[0];
var id=_9[1];
var _c=document.getElementById(id);
if(_a&&_c.nodeName.toLowerCase()!=_a){
return new Array();
}
_7=new Array(_c);
continue;
}
if(token.indexOf(".")>-1){
var _d=token.split(".");
var _e=_d[0];
var _f=_d[1];
if(!_e){
_e="*";
}
var _10=new Array;
var _11=0;
for(var h=0;h<_7.length;h++){
var _13;
if(_e=="*"){
_13=getAllChildren(_7[h]);
}else{
_13=_7[h].getElementsByTagName(_e);
}
for(var j=0;j<_13.length;j++){
_10[_11++]=_13[j];
}
}
_7=new Array;
var _15=0;
for(var k=0;k<_10.length;k++){
if(_10[k].className&&_10[k].className.match(new RegExp("\\b"+_f+"\\b"))){
_7[_15++]=_10[k];
}
}
continue;
}
if(token.match(/^(\w*)\[(\w+)([=~\|\^\$\*]?)=?"?([^\]"]*)"?\]$/)){
var _17=RegExp.$1;
var _18=RegExp.$2;
var _19=RegExp.$3;
var _1a=RegExp.$4;
if(!_17){
_17="*";
}
var _1b=new Array;
var _1c=0;
for(var h=0;h<_7.length;h++){
var _1e;
if(_17=="*"){
_1e=getAllChildren(_7[h]);
}else{
_1e=_7[h].getElementsByTagName(_17);
}
for(var j=0;j<_1e.length;j++){
_1b[_1c++]=_1e[j];
}
}
_7=new Array;
var _20=0;
var _21;
switch(_19){
case "=":
_21=function(e){
return (e.getAttribute(_18)==_1a);
};
break;
case "~":
_21=function(e){
return (e.getAttribute(_18).match(new RegExp("\\b"+_1a+"\\b")));
};
break;
case "|":
_21=function(e){
return (e.getAttribute(_18).match(new RegExp("^"+_1a+"-?")));
};
break;
case "^":
_21=function(e){
return (e.getAttribute(_18).indexOf(_1a)==0);
};
break;
case "$":
_21=function(e){
return (e.getAttribute(_18).lastIndexOf(_1a)==e.getAttribute(_18).length-_1a.length);
};
break;
case "*":
_21=function(e){
return (e.getAttribute(_18).indexOf(_1a)>-1);
};
break;
default:
_21=function(e){
return e.getAttribute(_18);
};
}
_7=new Array;
var _29=0;
for(var k=0;k<_1b.length;k++){
if(_21(_1b[k])){
_7[_29++]=_1b[k];
}
}
continue;
}
if(!_7[0]){
return;
}
_17=token;
var _2b=new Array;
var _2c=0;
for(var h=0;h<_7.length;h++){
var _2e=_7[h].getElementsByTagName(_17);
for(var j=0;j<_2e.length;j++){
_2b[_2c++]=_2e[j];
}
}
_7=_2b;
}
return _7;
};

