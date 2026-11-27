// Real service/browser smoke test. Invoked by web_playback_browser_test.dart.
// Pairing configuration is supplied on stdin, never command-line arguments.
import {readFile, mkdir} from 'node:fs/promises';
import assert from 'node:assert/strict';
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
 console.log('Browser pairing, playback, seek, progress resume, logout and 390px layout passed.');
} finally {await browser.close();}
