// Real service/browser smoke test. Invoked by web_playback_browser_test.dart.
// Pairing configuration is supplied on stdin, never command-line arguments.
import {readFile, mkdir} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {resolve} from 'node:path';
const {chromium} = await import(process.env.OPX_PLAYWRIGHT_MODULE || 'playwright');
const chunks=[];
for await (const chunk of process.stdin) chunks.push(chunk);
const {address,code}=JSON.parse(Buffer.concat(chunks).toString());
const browser=await chromium.launch({
  executablePath:process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless:true,args:['--autoplay-policy=no-user-gesture-required'],
});
try {
 const page=await browser.newPage({viewport:{width:1100,height:900},locale:'en-US'});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(address);
 await page.locator('#pair:visible').waitFor();
 await page.locator('#device').fill('Browser smoke test');
 await page.locator('#code').fill(code);
 await page.locator('#pair-form button').click();
 await page.locator('.media').waitFor();
 await page.locator('.media').click();
 await page.waitForFunction(()=>document.getElementById('video').currentTime>.3);
 await page.evaluate(async()=>{const v=document.getElementById('video');v.pause();v.currentTime=6;await new Promise(r=>v.addEventListener('seeked',r,{once:true}));await v.play();});
 await page.waitForFunction(()=>document.getElementById('video').currentTime>6.2);
 await page.evaluate(()=>document.getElementById('video').pause());
 await page.waitForFunction(()=>document.getElementById('play-status').textContent==='Playback progress saved');
 await mkdir('build/web-playback',{recursive:true});
 await page.screenshot({path:'build/web-playback/browser-desktop.png',fullPage:true});
 await page.locator('#close-player').click();
 await page.locator('#player').waitFor({state:'hidden'});
 await page.reload();
 await page.locator('.media').waitFor();
 assert.match(await page.locator('.resume').textContent(),/Resume/);
 await page.setViewportSize({width:390,height:844});
 await page.reload();
 await page.locator('.media').waitFor();
 await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true,'mobile overflow');
 await page.screenshot({path:'build/web-playback/browser-mobile.png',fullPage:true});
 await page.locator('#logout').click();
 await page.locator('#pair:visible').waitFor();
 assert.deepEqual(errors,[]);
 // The packaged launcher validates its destination and remembers only its address.
 const launcher=await browser.newPage({viewport:{width:1920,height:1080},locale:'en-US'});
 launcher.on('pageerror',e=>errors.push(e.message));
 const launcherUrl=pathToFileURL(resolve('webos/index.html')).href;
 await launcher.goto(launcherUrl);
 await launcher.locator('#address').fill('https://example.com');
 await launcher.locator('#open').click();
 assert.match(await launcher.locator('#message').textContent(),/private IPv4/);
 for(const invalid of ['http://127.0.0.1:8090','http://192.168.1.2:8090/path','http://user:pass@192.168.1.2:8090','http://192.168.1.2:8090/?tv=1']){
  await launcher.locator('#address').fill(invalid);await launcher.locator('#open').click();
  assert.equal(launcher.url(),launcherUrl);
 }
 await launcher.keyboard.press('Escape');
 assert.equal(await launcher.locator('#cancel').evaluate(n=>n===document.activeElement),true);
 await launcher.keyboard.press('Escape');
 await launcher.route('http://192.168.1.2:8090/**',r=>r.fulfill({contentType:'text/html',body:'Connected'}));
 await launcher.locator('#address').fill('http://192.168.1.2:8090');
 await launcher.locator('#open').click();
 await launcher.waitForURL('http://192.168.1.2:8090/?tv=1');
 await launcher.goto(launcherUrl);
 assert.equal(await launcher.locator('#address').inputValue(),'http://192.168.1.2:8090');
 assert.equal(await launcher.locator('#open').evaluate(n=>n===document.activeElement),true);
 await launcher.close();

 // Both TV clients use the real Dart service. Tizen stays on a packaged
 // file origin and exercises the separate cookie-free bearer boundary.
 for(const platform of ['webos','tizen']){
 const samsung=platform==='tizen';
 const tv=await browser.newPage({viewport:{width:1920,height:1080},locale:'en-US',userAgent:samsung?'Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.5) AppleWebKit/537.36 Chrome/85.0.4183.93 TV Safari/537.36':'Mozilla/5.0 (Web0S; Linux/SmartTV) AppleWebKit/537.36 Chrome/79.0.3945.79 Safari/537.36 WebAppManager'});
 const start=samsung?pathToFileURL(resolve('build/tizen/widget/player.html')).href:address+'/?tv=1';
 if(samsung){
  await tv.addInitScript(server=>{
   localStorage.setItem('opx.tizen.server',server);
   window.registeredKeys=[];window.exitCalls=0;
   window.tizen={tvinputdevice:{registerKey(name){window.registeredKeys.push(name);if(name==='MediaRewind')throw Error('Unsupported key');}},application:{getCurrentApplication:()=>({exit(){window.exitCalls++;}})}};
  },address);
 }

 tv.on('pageerror',e=>errors.push(e.message));
 if(samsung){
  await tv.goto(pathToFileURL(resolve('build/tizen/widget/index.html')).href);
  assert.equal(await tv.locator('h1 small').textContent(),'Samsung TV');
  await tv.screenshot({path:'build/web-playback/tizen-launcher.png',fullPage:true});
  await tv.locator('#open').click();
  await tv.waitForURL(start);
 }else await tv.goto(start);
 await tv.locator('html.tv').waitFor();
 await tv.waitForFunction(()=>document.activeElement.id==='device');
 assert.equal(await tv.locator('#device').inputValue(),samsung?'Samsung Tizen TV':'LG webOS TV');
 if(samsung)assert.deepEqual(await tv.evaluate(()=>window.registeredKeys),['MediaPlay','MediaPause','MediaPlayPause','MediaStop','MediaRewind','MediaFastForward']);
 await tv.keyboard.press('ArrowDown');
 assert.equal(await tv.locator('#code').evaluate(n=>n===document.activeElement),true);
 await tv.keyboard.type(code);
 await tv.keyboard.press('ArrowDown');
 await tv.keyboard.press('Enter');
 await tv.waitForFunction(()=>document.activeElement.className==='media');
 await tv.screenshot({path:'build/web-playback/'+platform+'-library.png',fullPage:true});
 await tv.evaluate(()=>window.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',repeat:true,bubbles:true})));
 assert.equal(await tv.locator('#player').isVisible(),false,'held OK must not activate');
 await tv.keyboard.press('Enter');
 await tv.waitForFunction(()=>document.getElementById('video').currentTime>.3);
 assert.equal(await tv.locator('#video').evaluate(n=>n.controls),false);
 assert.equal(await tv.locator('#tv-toggle').evaluate(n=>n===document.activeElement),true);
 await tv.keyboard.press('Enter');
 await tv.waitForFunction(()=>document.getElementById('video').paused);
 await tv.evaluate(()=>window.dispatchEvent(new KeyboardEvent('keydown',{keyCode:415,bubbles:true})));
 await tv.waitForFunction(()=>!document.getElementById('video').paused);
 await tv.evaluate(()=>window.dispatchEvent(new KeyboardEvent('keydown',{keyCode:19,bubbles:true})));
 await tv.waitForFunction(()=>document.getElementById('video').paused);
 if(samsung){
  await tv.evaluate(()=>window.dispatchEvent(new KeyboardEvent('keydown',{keyCode:10252,bubbles:true})));
  await tv.waitForFunction(()=>!document.getElementById('video').paused);
  await tv.evaluate(()=>window.dispatchEvent(new KeyboardEvent('keydown',{keyCode:10252,bubbles:true})));
  await tv.waitForFunction(()=>document.getElementById('video').paused);
 }
 await tv.locator('#video').evaluate(async v=>{v.currentTime=.5;await new Promise(r=>v.addEventListener('seeked',r,{once:true}));});
 await tv.keyboard.press('ArrowRight');
 assert.equal(await tv.locator('#tv-seek').evaluate(n=>n===document.activeElement),true);
 const before=await tv.locator('#video').evaluate(n=>n.currentTime);
 await tv.keyboard.press('ArrowRight');
 assert.equal(await tv.locator('#video').evaluate(n=>n.currentTime),before,'seek must await OK');
 await tv.keyboard.press('Escape');
 assert.equal(await tv.locator('#player').isVisible(),true);
 assert.equal(await tv.locator('#video').evaluate(n=>n.currentTime),before);
 await tv.keyboard.press('ArrowRight');
 await tv.keyboard.press('Enter');
 await tv.waitForFunction(t=>document.getElementById('video').currentTime>t,before);
 await tv.keyboard.press('Tab');
 assert.equal(await tv.locator('#tv-stop').evaluate(n=>n===document.activeElement),true);
 await tv.keyboard.press('Tab');
 assert.equal(await tv.locator('#close-player').evaluate(n=>n===document.activeElement),true);
 await tv.screenshot({path:'build/web-playback/'+platform+'-player.png',fullPage:true});
 await tv.evaluate(keyCode=>window.dispatchEvent(new KeyboardEvent('keydown',{keyCode,bubbles:true})),samsung?10009:461);
 await tv.locator('#player').waitFor({state:'hidden'});
 assert.equal(await tv.locator('.media').evaluate(n=>n===document.activeElement),true,'Back restores launching tile');
 await tv.keyboard.press('Escape');
 assert.equal(await tv.locator('#tv-exit-cancel').evaluate(n=>n===document.activeElement),true);
 await tv.keyboard.press('Tab');
 assert.equal(await tv.locator('#tv-exit-confirm').evaluate(n=>n===document.activeElement),true);
 await tv.keyboard.press('Escape');
 assert.equal(await tv.locator('.media').evaluate(n=>n===document.activeElement),true);
 if(samsung){
  await tv.keyboard.press('Escape');
  await tv.locator('#tv-exit-confirm').click();
  assert.equal(await tv.evaluate(()=>window.exitCalls),1);
 }
 await tv.goto(samsung?start:address); // user agent alone selects TV
 await tv.locator('html.tv').waitFor();
 await tv.locator('.media').waitFor();
 await tv.locator('#logout').click();
 await tv.locator('#pair:visible').waitFor();
 assert.deepEqual(errors,[]);
 await tv.close();
 }
 console.log('Desktop/mobile playback, webOS and packaged Tizen clients, pairing, D-pad, seek confirmation, Back, focus restoration and logout passed.');
} finally {await browser.close();}
