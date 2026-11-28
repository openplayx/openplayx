'use strict';
(()=>{
// The widget stays packaged so Tizen native APIs remain available. All API
// requests omit cookies and use the separately paired, short-lived TV token.
let address='';
try{address=localStorage.getItem('opx.tizen.server')||'';}catch{}
try{
 const u=new URL(address),ip=u.hostname.split('.').map(Number);
 if(u.protocol!=='http:'||u.username||u.password||u.pathname!=='/'||u.search||u.hash||ip.length!==4||ip.some(n=>!Number.isInteger(n)||n<0||n>255)||!(ip[0]===10||ip[0]===172&&ip[1]>=16&&ip[1]<=31||ip[0]===192&&ip[1]===168))throw Error('address');
 // A changed server must not receive another server's bearer credential.
 let token='';if(sessionStorage.getItem('opx.tizen.token-server')===u.origin)token=sessionStorage.getItem('opx.tizen.token')||'';
 else sessionStorage.removeItem('opx.tizen.token');
 sessionStorage.setItem('opx.tizen.token-server',u.origin);
 window.opxTvClient={address:u.origin,token};
}catch{location.replace('index.html');}
})();
