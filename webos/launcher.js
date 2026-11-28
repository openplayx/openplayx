'use strict';
(()=>{
// Shared launcher; the Tizen builder supplies data-platform="tizen".
const samsung=document.documentElement.dataset.platform==='tizen';
const storageKey=samsung?'opx.tizen.server':'opx.webos.server';
const zh=navigator.language.toLowerCase().indexOf('zh')===0;
const labels=zh?{help:'在电脑端打开 OpenPlayX → 设置 → Web 播放，开启服务并选择分享的媒体库。输入显示的局域网地址，然后使用配对码连接。',address:'电脑端服务地址',open:'连接媒体库',note:'需要 webOS 6.0 或更新版本。电脑端需保持运行。仅支持电视可直接解码的媒体格式。',exit:'退出',exitTitle:'退出 OpenPlayX？',cancel:'取消',error:'请输入电脑端显示的 HTTP 局域网 IPv4 地址，例如 http://192.168.1.10:8090。'}:{help:'On your computer, open OpenPlayX → Settings → Web playback. Enable the service and select library folders to share. Enter the LAN address shown there, then use its pairing code.',address:'Desktop service address',open:'Connect to library',note:'Requires webOS 6.0 or later. Keep the desktop app running. Only formats supported by your TV can play directly.',exit:'Exit',exitTitle:'Exit OpenPlayX?',cancel:'Cancel',error:'Enter the HTTP private IPv4 address shown in the desktop app, such as http://192.168.1.10:8090.'};
if(samsung){labels.note=zh?'需要 Tizen 6.5 或更新版本。电脑端需保持运行。仅支持电视可直接解码的媒体格式。':'Requires Tizen 6.5 or later. Keep the desktop app running. Only formats supported by your TV can play directly.';document.querySelector('h1 small').textContent='Samsung TV';}
const $=id=>document.getElementById(id);
document.documentElement.lang=zh?'zh':'en';
for(const pair of [['help','help'],['address-label','address'],['open','open'],['note','note'],['exit','exit'],['exit-title','exitTitle'],['cancel','cancel'],['confirm','exit']])$(pair[0]).textContent=labels[pair[1]];
let saved='';try{saved=localStorage.getItem(storageKey)||'';}catch{}
$('address').value=saved;
(saved?$('open'):$('address')).focus();
function parseAddress(value){
 const u=new URL(value.trim());
 const parts=u.hostname.split('.').map(Number);
 if(u.protocol!=='http:'||u.username||u.password||u.pathname!=='/'||u.search||u.hash||parts.length!==4||parts.some(n=>!Number.isInteger(n)||n<0||n>255)||!(parts[0]===10||parts[0]===172&&parts[1]>=16&&parts[1]<=31||parts[0]===192&&parts[1]===168))throw Error('address');
 return u.origin;
}
$('connect').addEventListener('submit',e=>{e.preventDefault();try{const address=parseAddress($('address').value);try{localStorage.setItem(storageKey,address);}catch{}location.replace(samsung?'player.html':address+'/?tv=1');}catch{$('message').textContent=labels.error;$('address').focus();}});
function dismiss(){$('exit-dialog').hidden=true;$('exit').focus();}
function showExit(){$('exit-dialog').hidden=false;$('cancel').focus();}
$('exit').onclick=showExit;$('cancel').onclick=dismiss;$('confirm').onclick=()=>{try{if(samsung&&window.tizen&&tizen.application){tizen.application.getCurrentApplication().exit();return;}}catch{}window.close();};
window.addEventListener('keydown',e=>{
 const key=e.key&&e.key!=='Unidentified'?e.key:({13:'Enter',37:'ArrowLeft',38:'ArrowUp',39:'ArrowRight',40:'ArrowDown'})[e.keyCode];
 if(e.keyCode===461||e.keyCode===10009||key==='Escape'){e.preventDefault();if(!e.repeat){if($('exit-dialog').hidden)showExit();else dismiss();}return;}
 const nodes=$('exit-dialog').hidden?[$('address'),$('open'),$('exit')]:[$('cancel'),$('confirm')];
 if(key==='Tab'||key==='ArrowUp'||key==='ArrowDown'||(document.activeElement.tagName!=='INPUT'&&(key==='ArrowLeft'||key==='ArrowRight'))){e.preventDefault();const direction=e.shiftKey||key==='ArrowUp'||key==='ArrowLeft'?-1:1;nodes[(nodes.indexOf(document.activeElement)+direction+nodes.length)%nodes.length].focus();}
 if(key==='Enter'&&document.activeElement.tagName==='BUTTON'&&e.repeat)e.preventDefault();
});
})();
