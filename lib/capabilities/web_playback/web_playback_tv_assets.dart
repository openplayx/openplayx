// Shared hosted/packaged TV presentation of the LAN player. Compatible with
// Chromium 79 (webOS 6.x) / Chromium 85 (Tizen 6.5). No source credentials.
const webPlaybackTvCss = r'''
html.tv{color-scheme:dark;--bg:#101014;--panel:#1c1c24;--text:#f4f4f8;--muted:#b5b5c4;--line:#444452;--accent:#ff9638;--onaccent:#17120c;--soft:#292430}
.tv body{font-size:24px}.tv header{padding:28px 5vw}.tv .brand{font-size:32px}.tv .tag{font-size:18px;margin-left:20px}.tv .logo{margin-right:10px}.tv #search-form button{margin-left:12px}.tv main{max-width:none;padding:36px 5vw}.tv h1{font-size:44px}.tv h2{font-size:30px}.tv button,.tv input{min-height:64px;padding:12px 20px}.tv button:focus,.tv input:focus,.tv a:focus{outline:4px solid var(--accent);outline-offset:5px}.tv .eyebrow{font-size:16px}.tv #pair{max-width:680px;margin:24px auto}.tv #pair-form{gap:12px}.tv #code{font-size:32px}.tv #search{max-width:320px}.tv #grid{grid-template-columns:repeat(4,minmax(0,1fr));gap:32px}.tv .cover{height:210px}.tv .media strong{font-size:24px}.tv .file,.tv .resume{font-size:19px}.tv footer{font-size:20px}.tv .format{font-size:16px}
.tv.playing{overflow:hidden}.tv.playing #player{position:fixed;top:0;right:0;bottom:0;left:0;z-index:10;border:0;border-radius:0;background:#000;padding:32px 5vw;display:flex;flex-direction:column}.tv.playing header,.tv.playing .heading,.tv.playing #grid,.tv.playing #more,.tv.playing #empty,.tv.playing footer{display:none!important}.tv.playing video{flex:1;min-height:0;width:100%;max-height:none;object-fit:contain}.tv .player-foot{font-size:20px}.tv.playing #message{position:fixed;bottom:150px;left:5vw;right:5vw;z-index:11;background:#19191f}.tv.playing #message:empty{display:none}.tv-controls{display:flex;align-items:center;margin-top:20px}.tv-controls button{margin-right:20px}.tv-controls #tv-seek{flex:1;text-align:center}.tv-exit{position:fixed;top:0;right:0;bottom:0;left:0;background:rgba(0,0,0,.94);z-index:30;display:flex;align-items:center;justify-content:center}.tv-exit section{padding:48px;background:var(--panel);border-radius:16px;max-width:800px}.tv-exit button{margin:24px 24px 0 0}
''';

const webPlaybackTvJs = r'''
'use strict';
(()=>{
const samsung=!!window.opxTvClient||/Tizen/i.test(navigator.userAgent)||new URLSearchParams(location.search).get('platform')==='tizen';
const tv=samsung||new URLSearchParams(location.search).get('tv')==='1'||/Web0S|webOS|NetCast/i.test(navigator.userAgent);
if(!tv)return;
const $=id=>document.getElementById(id),video=$('video');
const zh=document.documentElement.lang==='zh';
const text=zh?{toggle:'播放 / 暂停',seek:'进度',hint:'左右预览 · 确定跳转 · 返回取消',exit:'退出 OpenPlayX？',yes:'退出',no:'继续观看',stop:'停止播放',error:'此媒体当前无法跳转。'}:{toggle:'Play / Pause',seek:'Position',hint:'Left/right to preview · OK to seek · Back to cancel',exit:'Exit OpenPlayX?',yes:'Exit',no:'Keep watching',stop:'Stop playback',error:'Seeking is unavailable for this media.'};
document.documentElement.classList.add('tv');
$('device').value=samsung?'Samsung Tizen TV':/Web0S|webOS|NetCast/i.test(navigator.userAgent)?'LG webOS TV':'TV';
// Media keys require explicit registration in the Tizen application runtime.
if(samsung&&window.tizen&&tizen.tvinputdevice){
 const input=tizen.tvinputdevice;
 for(const name of ['MediaPlay','MediaPause','MediaPlayPause','MediaStop','MediaRewind','MediaFastForward']){try{input.registerKey(name);}catch{}}
}
// The brand link would drop ?tv=1 in a desktop TV preview.
document.querySelector('.brand').href=window.opxTvClient?'index.html':'/?tv=1'+(samsung?'&platform=tizen':'');
video.controls=false;video.tabIndex=-1;
const controls=document.createElement('div');controls.className='tv-controls';
function button(id,label){const b=document.createElement('button');b.type='button';b.id=id;b.textContent=label;return b;}
const toggle=button('tv-toggle',text.toggle),seek=button('tv-seek',text.seek),stop=button('tv-stop',text.stop);
seek.setAttribute('role','slider');seek.setAttribute('aria-label',text.seek);seek.setAttribute('aria-valuemin','0');seek.setAttribute('aria-valuemax','0');seek.setAttribute('aria-valuenow','0');
controls.append(toggle,seek,stop);$('player').append(controls);
const exit=document.createElement('div');exit.className='tv-exit';exit.hidden=true;exit.setAttribute('role','dialog');exit.setAttribute('aria-modal','true');exit.setAttribute('aria-labelledby','tv-exit-title');
const panel=document.createElement('section'),title=document.createElement('h2');title.id='tv-exit-title';title.textContent=text.exit;
const cancel=button('tv-exit-cancel',text.no),confirm=button('tv-exit-confirm',text.yes);panel.append(title,cancel,confirm);exit.append(panel);document.body.append(exit);
let origin=null,exitOrigin=null,preview=null;
function focus(node){if(node&&!node.disabled&&node.getClientRects().length){node.focus();node.scrollIntoView({block:'nearest',inline:'nearest'});}}
function candidates(){const root=!exit.hidden?exit:!$('player').hidden?$('player'):document;return Array.from(root.querySelectorAll('button,input,a[href]')).filter(n=>!n.disabled&&n.tabIndex!==-1&&n.getClientRects().length);}
function first(){focus(candidates()[0]);}
function move(dx,dy){const nodes=candidates(),active=document.activeElement;if(!nodes.includes(active)){first();return;}const a=active.getBoundingClientRect(),ax=a.left+a.width/2,ay=a.top+a.height/2;let best=null,score=Infinity;
 for(const n of nodes){if(n===active)continue;const b=n.getBoundingClientRect(),x=b.left+b.width/2-ax,y=b.top+b.height/2-ay;const forward=dx?x*dx:y*dy;if(forward<=1)continue;const across=Math.abs(dx?y:x),value=forward+across*3;if(value<score){best=n;score=value;}}
 focus(best);
}
function seconds(value){const t=Math.floor(value||0);return Math.floor(t/60)+':'+String(t%60).padStart(2,'0');}
function update(){const duration=Number.isFinite(video.duration)?video.duration:0;const position=preview===null?video.currentTime:preview;seek.textContent=seconds(position)+' / '+seconds(duration)+(preview===null?'':' · '+text.hint);seek.setAttribute('aria-valuemax',String(Math.floor(duration)));seek.setAttribute('aria-valuenow',String(Math.floor(position||0)));seek.setAttribute('aria-valuetext',seek.textContent);toggle.setAttribute('aria-pressed',String(!video.paused));}
function change(delta){if(!Number.isFinite(video.duration)||video.duration<=0)return;preview=Math.max(0,Math.min(video.duration,(preview===null?video.currentTime:preview)+delta));update();}
function commit(){if(preview===null)return;try{video.currentTime=preview;}catch{$('message').textContent=text.error;}preview=null;update();}
function togglePlayback(){if($('player').hidden)return;if(video.paused)video.play().catch(()=>{$('message').textContent=zh?'无法播放此媒体。':'Unable to play this media.';});else video.pause();}
toggle.onclick=togglePlayback;seek.onclick=commit;stop.onclick=()=>$('close-player').click();
video.addEventListener('timeupdate',update);video.addEventListener('loadedmetadata',update);video.addEventListener('play',update);video.addEventListener('pause',update);
seek.addEventListener('blur',()=>{preview=null;update();});
function dismissExit(){exit.hidden=true;focus(exitOrigin);}
cancel.onclick=dismissExit;confirm.onclick=()=>{try{if(samsung&&window.tizen&&tizen.application){tizen.application.getCurrentApplication().exit();return;}}catch{}window.close();};
function back(){if(!exit.hidden){dismissExit();return;}if(preview!==null){preview=null;update();return;}if(!$('player').hidden){$('close-player').click();return;}exitOrigin=document.activeElement;exit.hidden=false;focus(cancel);}
document.addEventListener('opx:authenticated',e=>focus(e.detail.ok?$('logout'):$('device')));
document.addEventListener('opx:library',()=>{if($('player').hidden&&(document.activeElement===document.body||document.activeElement===$('logout')||!document.activeElement.getClientRects().length))focus($('grid').querySelector('button')||$('search'));});
document.addEventListener('opx:player-opened',e=>{origin=e.detail.trigger;preview=null;document.documentElement.classList.add('playing');focus(toggle);update();});
document.addEventListener('opx:player-closed',()=>{document.documentElement.classList.remove('playing');preview=null;if(!$('pair').hidden)focus($('device'));else if(origin&&origin.isConnected)focus(origin);else first();origin=null;});
document.addEventListener('visibilitychange',()=>{if(document.hidden)video.pause();});
window.addEventListener('keydown',e=>{const code=e.keyCode;const key=e.key&&e.key!=='Unidentified'?e.key:({13:'Enter',37:'ArrowLeft',38:'ArrowUp',39:'ArrowRight',40:'ArrowDown'})[code];
 if(code===461||code===10009||key==='Escape'||(key==='Backspace'&&document.activeElement.tagName!=='INPUT')){e.preventDefault();if(!e.repeat)back();return;}
 const active=document.activeElement,isInput=active.tagName==='INPUT';
 if(key==='Tab'){e.preventDefault();const nodes=candidates(),i=nodes.indexOf(active);focus(nodes[(i+(e.shiftKey?-1:1)+nodes.length)%nodes.length]);return;}
 if((code===415||code===19||code===179||code===10252||code===413||code===412||code===417)&&!$('player').hidden){e.preventDefault();if(e.repeat)return;if(code===415)video.play().catch(()=>{});else if(code===19)video.pause();else if(code===413)$('close-player').click();else if(code===412||code===417){change(code===412?-10:10);commit();}else togglePlayback();return;}
 if(active===seek&&(key==='ArrowLeft'||key==='ArrowRight')){e.preventDefault();change(key==='ArrowLeft'?-10:10);return;}
 if(key==='ArrowUp'||key==='ArrowDown'||(!isInput&&(key==='ArrowLeft'||key==='ArrowRight'))){e.preventDefault();move(key==='ArrowLeft'?-1:key==='ArrowRight'?1:0,key==='ArrowUp'?-1:key==='ArrowDown'?1:0);return;}
 if(key==='Enter'&&!isInput){e.preventDefault();if(!e.repeat&&candidates().includes(active))active.click();}
});
first();
})();
''';
