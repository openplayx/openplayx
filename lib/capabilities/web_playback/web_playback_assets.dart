// Self-contained, same-origin assets. No CDN, source credentials or inline
// scripts: the HTTP boundary applies a restrictive Content Security Policy.
const webPlaybackHtml = r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light dark"><title>OpenPlayX</title><link rel="stylesheet" href="/app.css"><link rel="stylesheet" href="/tv.css"><script src="/app.js" defer></script><script src="/tv.js" defer></script></head>
<body><header><a href="/" class="brand"><span class="logo">▶</span>OpenPlayX</a><span class="tag" data-i="lan"></span><button id="logout" hidden data-i="disconnect"></button></header>
<main><section id="pair"><div class="eyebrow">WEB PLAYER</div><h1 data-i="pairTitle"></h1><p data-i="pairHelp"></p><form id="pair-form"><label for="device" data-i="device"></label><input id="device" maxlength="80" required autocomplete="off"><label for="code" data-i="code"></label><input id="code" inputmode="numeric" pattern="[0-9]{6}" maxlength="6" required autocomplete="one-time-code"><button class="primary" type="submit" data-i="connect"></button></form></section>
<div id="library" hidden><div class="heading"><div><div class="eyebrow">YOUR LIBRARY</div><h1 data-i="library"></h1><p data-i="directHelp"></p></div><form id="search-form"><label class="sr" for="search" data-i="search"></label><input id="search" maxlength="200"><button data-i="search"></button></form></div>
<section id="player" hidden><div class="player-heading"><h2 id="playing-title"></h2><button id="close-player" data-i="close"></button></div><video id="video" controls playsinline preload="metadata"></video><div class="player-foot"><span data-i="direct"></span><span id="play-status" role="status"></span></div></section>
<p id="empty" hidden data-i="empty"></p><div id="grid"></div><button id="more" hidden data-i="more"></button></div>
<p id="message" role="status" aria-live="polite"></p></main><footer data-i="keepOpen"></footer></body></html>''';

const webPlaybackCss = r'''
:root{--bg:#13151b;--panel:#1d2028;--text:#eceef4;--muted:#a6aebf;--line:#343a48;--accent:#b5a5ff;--onaccent:#19152d;--soft:#302943} @supports(color:light-dark(white,black)){:root{color-scheme:light dark;--bg:light-dark(#f7f8fb,#13151b);--panel:light-dark(#fff,#1d2028);--text:light-dark(#232b3a,#eceef4);--muted:light-dark(#697386,#a6aebf);--line:light-dark(#e3e6ef,#343a48);--accent:light-dark(#6652d8,#b5a5ff);--onaccent:light-dark(#fff,#19152d);--soft:light-dark(#edeafb,#302943)}}*{box-sizing:border-box}body{margin:0;font:14px/1.6 system-ui,-apple-system,"PingFang SC",sans-serif;color:var(--text);background:var(--bg)}[hidden]{display:none!important}header{display:flex;gap:20px;align-items:center;background:var(--panel);border-bottom:1px solid var(--line);padding:20px max(24px,calc((100vw - 1100px)/2))}.brand{display:flex;gap:10px;align-items:center;color:inherit;text-decoration:none;font-size:20px;font-weight:600;letter-spacing:-.6px}.logo{background:var(--accent);color:var(--onaccent);border-radius:10px;padding:0 9px;font-size:19px}.tag{font-size:11px;border:1px solid var(--line);border-radius:30px;padding:3px 10px;color:var(--muted)}#logout{margin-left:auto}main{max-width:1100px;margin:auto;padding:40px 24px}h1{font-size:30px;letter-spacing:-1px;font-weight:600;margin:6px 0 10px}h2{font-size:18px;font-weight:500;margin:0}p{color:var(--muted);margin:0 0 20px}.eyebrow{font-size:10px;letter-spacing:2px;color:var(--muted)}button,input{font:inherit}button{border:1px solid var(--line);background:var(--panel);color:var(--text);padding:9px 15px;border-radius:8px;cursor:pointer;min-height:42px}button:hover{border-color:var(--accent)}button:disabled{opacity:.5;cursor:wait}button.primary{background:var(--accent);color:var(--onaccent);border-color:var(--accent)}input{background:var(--panel);border:1px solid var(--line);color:var(--text);border-radius:8px;padding:11px 13px;min-width:0;width:100%}input:focus-visible,button:focus-visible,a:focus-visible{outline:2px solid var(--accent);outline-offset:3px}#pair{max-width:400px;margin:50px auto}#pair-form{display:grid;gap:9px}#pair-form label{margin-top:10px}#pair-form button{margin-top:15px}#code{letter-spacing:8px;font-size:22px}.heading{display:flex;justify-content:space-between;gap:20px;align-items:center;flex-wrap:wrap;margin-bottom:24px}#search-form{display:flex;gap:8px;max-width:100%}#search{max-width:210px}#grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:22px}.media{border:0;text-align:left;background:none;padding:0;min-width:0;color:var(--text)}.cover{height:160px;background:var(--soft);border-radius:11px;padding:20px;display:flex;flex-direction:column;justify-content:space-between;overflow:hidden;position:relative}.cover::after{content:'';position:absolute;right:-40px;bottom:-70px;width:180px;height:220px;background:var(--accent);opacity:.1;transform:rotate(30deg);border-radius:45px}.cover-mark{font-size:32px;color:var(--accent)}.format{font-size:10px;letter-spacing:2px;color:var(--muted)}.media strong{display:block;font-size:14px;font-weight:500;margin:10px 0 3px;overflow-wrap:anywhere}.file{font-size:11px;color:var(--muted);display:block;overflow-wrap:anywhere}.resume{display:block;font-size:11px;margin-top:6px;color:var(--accent)}#more{display:block;margin:28px auto}#player{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:16px;margin:0 0 30px}.player-heading,.player-foot{display:flex;justify-content:space-between;align-items:center;gap:15px}.player-heading{margin-bottom:14px}video{width:100%;max-height:65vh;background:#000;display:block;border-radius:6px}.player-foot{font-size:11px;color:var(--muted);margin-top:12px;flex-wrap:wrap}#message{margin-top:22px;color:var(--accent)}footer{text-align:center;color:var(--muted);font-size:11px;margin:30px 20px}.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip-path:inset(50%)}@media(max-width:550px){header{padding:16px;gap:10px}.brand{font-size:18px}.tag{display:none}main{padding:25px 16px}#grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}.cover{height:145px}#pair{margin:25px auto}.player-heading{align-items:start}h1{font-size:26px}}
''';

const webPlaybackJs = r'''
'use strict';
(()=>{
const zh=navigator.language.toLowerCase().startsWith('zh');
const strings=zh?{
lan:'局域网',disconnect:'断开连接',pairTitle:'连接到你的媒体库',pairHelp:'在桌面端开启 Web 播放服务，然后输入配对码。',device:'设备名称',code:'6 位配对码',connect:'连接媒体库',library:'好内容，接着看。',directHelp:'原画直出 · 支持情况取决于当前浏览器',search:'搜索',close:'关闭播放',direct:'原画直出',empty:'还没有分享的媒体。请在桌面端选择分享范围并完成媒体扫描。',more:'加载更多',keepOpen:'保持 OpenPlayX 运行，并连接到同一局域网。',resume:'继续观看',play:'播放',pairing_required:'请重新配对。',invalid_pairing_code:'配对码不正确或已过期。',pairing_rate_limited:'尝试次数过多，请一分钟后重试。',device_limit:'连接设备已达上限，请在桌面端重启服务。',media_unavailable:'媒体暂不可用，请检查桌面端的数据源连接。',session_ended:'会话已结束，或该媒体已停止分享。',not_shared:'此媒体已停止分享。',unsupported:'当前浏览器无法播放此格式。此版本暂不提供转码，请尝试其他媒体或使用原生 App。',source_requires_gateway:'此数据源暂不支持浏览器播放。',offline:'无法连接服务，请检查网络和桌面端服务状态。',progressError:'进度同步失败，正在重试…',saved:'播放进度已同步',connected:'已连接',invalid_request:'请求无效。',busy:'服务繁忙，请稍后重试。',playback_limit:'播放会话已达上限。',session_replaced:'已切换到另一个播放请求。'
}:{lan:'Local network',disconnect:'Disconnect',pairTitle:'Connect to your library',pairHelp:'Enable Web playback in the desktop app, then enter its pairing code.',device:'Device name',code:'6-digit pairing code',connect:'Connect to library',library:'Pick up where you left off.',directHelp:'Original quality · Format support depends on this browser',search:'Search',close:'Close player',direct:'Direct Play',empty:'No shared media yet. Select folders to share and finish scanning them in the desktop app.',more:'Load more',keepOpen:'Keep OpenPlayX running and stay on the same local network.',resume:'Resume',play:'Play',pairing_required:'Please pair this device again.',invalid_pairing_code:'The pairing code is incorrect or expired.',pairing_rate_limited:'Too many attempts. Try again in one minute.',device_limit:'Device limit reached. Restart the service in the desktop app.',media_unavailable:'Media unavailable. Check the source connection in the desktop app.',session_ended:'Playback ended or this media is no longer shared.',not_shared:'This media is no longer shared.',unsupported:'This browser cannot play this format. Transcoding is not available in this version. Try another title or the native app.',source_requires_gateway:'This source does not support browser playback yet.',offline:'Unable to connect. Check your network and the desktop service.',progressError:'Progress sync failed. Retrying…',saved:'Playback progress saved',connected:'Connected',invalid_request:'Invalid request.',busy:'Service busy. Try again shortly.',playback_limit:'Playback session limit reached.',session_replaced:'A newer playback request replaced this one.'};
const $=id=>document.getElementById(id),video=$('video'),native=window.opxTvClient;
document.documentElement.lang=zh?'zh':'en';
document.querySelectorAll('[data-i]').forEach(n=>n.textContent=strings[n.dataset.i]);
$('device').value=(/iPad|Tablet/i.test(navigator.userAgent)?'Tablet':/Mobi|iPhone/i.test(navigator.userAgent)?'Phone':'Browser')+' · '+(/Firefox/i.test(navigator.userAgent)?'Firefox':/Edg\//.test(navigator.userAgent)?'Edge':/Chrome/i.test(navigator.userAgent)?'Chrome':'Safari');
let current=null,serial=0,next=null,search='',syncing=false,listing=0;
const message=(text='')=>$('message').textContent=text;
function signal(state,detail={}){document.dispatchEvent(new CustomEvent('opx:'+state,{detail}));}
function authenticated(ok){$('pair').hidden=ok;$('library').hidden=!ok;$('logout').hidden=!ok;signal('authenticated',{ok});}
async function api(path,method='GET',body,keepalive=false){
 let response;
 const headers=method==='GET'?{}:{'Content-Type':'application/json','X-OpenPlayX':'1'};
 if(native){headers['X-OpenPlayX-TV']='1';if(native.token)headers.Authorization='Bearer '+native.token;}
 const url=native?native.address+path.replace('/api/','/tv-api/'):path;
 try{response=await fetch(url,{method,headers,body:body===undefined?undefined:JSON.stringify(body),credentials:native?'omit':'same-origin',cache:'no-store',keepalive});}catch{throw Error(strings.offline);}
 const data=await response.json();
 if(!response.ok){if(response.status===401){if(native){native.token='';sessionStorage.removeItem('opx.tizen.token');}authenticated(false);await closePlayer(false);}throw Error(strings[data.error]||strings.media_unavailable);}
 if(native&&path==='/api/pair'){native.token=data.token;sessionStorage.setItem('opx.tizen.token',data.token);}
 if(native&&path==='/api/logout'){native.token='';sessionStorage.removeItem('opx.tizen.token');}
 return data;
}
function clock(ms){const t=Math.floor(ms/1000);return Math.floor(t/3600)+':'+String(Math.floor(t/60)%60).padStart(2,'0')+':'+String(t%60).padStart(2,'0');}
async function load(append=false){
 const request=++listing;const offset=append?next:0;
 $('more').disabled=true;
 try{const data=await api('/api/library?offset='+offset+'&search='+encodeURIComponent(search));if(request!==listing)return;if(!append)$('grid').textContent='';
 for(const item of data.items){const button=document.createElement('button');button.className='media';button.type='button';const cover=document.createElement('div');cover.className='cover';const mark=document.createElement('span');mark.className='cover-mark';mark.textContent='▷';const format=document.createElement('span');format.className='format';format.textContent=item.name.split('.').pop().toUpperCase();cover.append(mark,format);const title=document.createElement('strong');title.textContent=item.title;const name=document.createElement('span');name.className='file';name.textContent=item.name;button.append(cover,title,name);if(item.positionMs>0){const resume=document.createElement('span');resume.className='resume';resume.textContent=strings.resume+' · '+clock(item.positionMs);button.append(resume);}button.onclick=()=>play(item);$('grid').append(button);}
 next=data.nextOffset;$('more').hidden=next===null;$('empty').hidden=$('grid').children.length>0;message();signal('library');
 }catch(e){message(e.message);}finally{$('more').disabled=false;}
}
async function progress(completed=false,keepalive=false){
 if(!current||!Number.isFinite(video.duration)||video.duration<=0||syncing)return;
 syncing=true;const id=current.id;
 try{await api('/api/playback/'+id+'/progress','POST',{positionMs:Math.round(Math.min(video.currentTime,video.duration)*1000),durationMs:Math.round(video.duration*1000),completed},keepalive);$('play-status').textContent=strings.saved;}
 catch(e){if(!current||current.id!==id)return;if(e.message===strings.session_ended){await closePlayer(false);message(e.message);}else $('play-status').textContent=strings.progressError;}
 finally{syncing=false;}
}
async function closePlayer(save=true){
 ++serial;
 const old=current;
 if(save&&old)await progress(video.ended);
 current=null;video.pause();video.removeAttribute('src');video.load();$('player').hidden=true;signal('player-closed');
 if(old)try{await api('/api/playback/'+old.id,'DELETE');}catch{}
}
async function play(item){
 const trigger=document.activeElement;
 await closePlayer();const request=++serial;message();
 try{const data=await api('/api/playback','POST',{id:item.id});if(request!==serial){await api('/api/playback/'+data.id,'DELETE');return;}current=data;$('playing-title').textContent=data.title;$('play-status').textContent='';$('player').hidden=false;signal('player-opened',{trigger});
 video.onloadedmetadata=()=>{if(current&&current.id===data.id&&data.positionMs>0&&data.positionMs/1000<video.duration-3)video.currentTime=data.positionMs/1000;};
 video.src=native?native.address+data.url:data.url;try{await video.play();}catch(e){if(e.name!=='NotAllowedError'&&e.name!=='AbortError')message(strings.unsupported);}$('player').scrollIntoView({behavior:'smooth',block:'nearest'});
 }catch(e){message(e.message);}
}
video.onerror=()=>{if(current)message(strings.unsupported);};
video.onpause=()=>{if(current)void progress();};video.onended=()=>void progress(true);
$('pair-form').onsubmit=async e=>{e.preventDefault();const button=$('pair-form').querySelector('button');button.disabled=true;try{await api('/api/pair','POST',{code:$('code').value,device:$('device').value});authenticated(true);$('code').value='';await load();}catch(e){message(e.message);}finally{button.disabled=false;}};
$('logout').onclick=async()=>{try{await closePlayer();await api('/api/logout','POST',{});authenticated(false);message();}catch(e){message(e.message);}};
$('search-form').onsubmit=e=>{e.preventDefault();search=$('search').value;void load();};$('more').onclick=()=>void load(true);$('close-player').onclick=()=>void closePlayer();
setInterval(()=>{if(current)void progress();},10000);
window.addEventListener('pagehide',()=>{void progress(video.ended,true);});
(async()=>{try{await api('/api/session');authenticated(true);await load();}catch(e){authenticated(false);if(e.message!==strings.pairing_required)message(e.message);}})();
})();
''';
