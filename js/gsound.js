/* game sounds, made in the browser with WebAudio (no files to download): wooden knocks, dice, cards, tiles, a turn chime,
   win and lose tunes. a short buzz on phones that support it. both follow one switch in the game menu */
const GS={ctx:null,on:store.get('gsnd',true),noise:null,last:{},bus:null};
function gsCtx(){if(!GS.on)return null;try{if(!GS.ctx){const C=window.AudioContext||window.webkitAudioContext;if(!C)return null;GS.ctx=new C();
  const comp=GS.ctx.createDynamicsCompressor();comp.threshold.value=-14;comp.ratio.value=4;comp.connect(GS.ctx.destination);GS.bus=comp;
  const n=GS.ctx.sampleRate,b=GS.ctx.createBuffer(1,n,n),d=b.getChannelData(0);for(let i=0;i<n;i++)d[i]=Math.random()*2-1;GS.noise=b}
 if(GS.ctx.state==='suspended')GS.ctx.resume().catch(()=>{});return GS.ctx}catch(e){return null}}
/* the browser lets sound start only after a touch, so the first touch anywhere wakes it */
['pointerdown','keydown'].forEach(k=>document.addEventListener(k,()=>{if(GS.on&&S.tab==='games')gsCtx()},{capture:true,passive:true}));
function gsEnv(g,t,a,peak,dec){g.gain.setValueAtTime(0.0001,t);g.gain.exponentialRampToValueAtTime(peak,t+a);g.gain.exponentialRampToValueAtTime(0.0001,t+a+dec)}
function gsNoise(x,t,{f=2000,q=1,type='bandpass',a=.002,peak=.3,dec=.06,rate=1}){const s=x.createBufferSource();s.buffer=GS.noise;s.playbackRate.value=rate;const fl=x.createBiquadFilter();fl.type=type;fl.frequency.value=f;fl.Q.value=q;
 const g=x.createGain();gsEnv(g,t,a,peak,dec);s.connect(fl);fl.connect(g);g.connect(GS.bus);s.start(t,Math.random()*.5);s.stop(t+a+dec+.05)}
function gsTone(x,t,{f=440,f2=null,type='sine',a=.004,peak=.2,dec=.12}){const o=x.createOscillator();o.type=type;o.frequency.setValueAtTime(f,t);if(f2)o.frequency.exponentialRampToValueAtTime(f2,t+a+dec);
 const g=x.createGain();gsEnv(g,t,a,peak,dec);o.connect(g);g.connect(GS.bus);o.start(t);o.stop(t+a+dec+.05)}
const GSND={
 wood:(x,t,v)=>{gsTone(x,t,{f:210+Math.random()*30,f2:110,peak:.42*v,dec:.09});gsNoise(x,t,{f:1700+Math.random()*400,q:1.6,peak:.32*v,dec:.045})},
 soft:(x,t,v)=>{gsTone(x,t,{f:260,f2:150,peak:.16*v,dec:.06});gsNoise(x,t,{f:2200,q:2,peak:.12*v,dec:.03})},
 cap:(x,t,v)=>{GSND.wood(x,t,v);gsNoise(x,t+.03,{f:3200,q:3,peak:.22*v,dec:.05});gsTone(x,t+.02,{f:520,f2:300,type:'triangle',peak:.08*v,dec:.08})},
 tile:(x,t,v)=>{gsTone(x,t,{f:430,f2:260,peak:.24*v,dec:.06});gsNoise(x,t,{f:3800,q:2.5,peak:.3*v,dec:.035})},
 card:(x,t,v)=>gsNoise(x,t,{f:3200,q:.7,type:'highpass',a:.006,peak:.22*v,dec:.07,rate:1.3}),
 deal:(x,t,v)=>{for(let k=0;k<4;k++)GSND.card(x,t+k*.07,v*.8)},
 dice:(x,t,v)=>{let s=t;for(let k=0;k<9;k++){s+=.035+Math.random()*.07;gsNoise(x,s,{f:2600+Math.random()*1800,q:4,peak:(.12+Math.random()*.2)*v,dec:.02})}
  gsTone(x,s+.05,{f:330,f2:180,peak:.25*v,dec:.06});gsNoise(x,s+.05,{f:2400,q:2,peak:.25*v,dec:.04});gsTone(x,s+.16,{f:300,f2:170,peak:.14*v,dec:.05})},
 tap:(x,t,v)=>gsTone(x,t,{f:940,f2:760,type:'triangle',peak:.07*v,dec:.05}),
 turn:(x,t,v)=>{gsTone(x,t,{f:660,type:'sine',peak:.12*v,dec:.18});gsTone(x,t+.09,{f:990,type:'sine',peak:.1*v,dec:.26})},
 check:(x,t,v)=>{gsTone(x,t,{f:740,type:'square',peak:.05*v,dec:.08});gsTone(x,t+.11,{f:740,type:'square',peak:.05*v,dec:.1})},
 win:(x,t,v)=>{[523,659,784,1047,1319].forEach((f,k)=>{gsTone(x,t+k*.11,{f,type:'triangle',peak:.16*v,dec:.35});gsTone(x,t+k*.11,{f:f*2,type:'sine',peak:.04*v,dec:.25})});gsNoise(x,t+.5,{f:6000,q:.5,type:'highpass',peak:.05*v,a:.05,dec:.8})},
 lose:(x,t,v)=>[392,349,311,262].forEach((f,k)=>gsTone(x,t+k*.16,{f,type:'sine',peak:.13*v,dec:.4})),
 draw:(x,t,v)=>[523,523,659].forEach((f,k)=>gsTone(x,t+k*.14,{f,type:'triangle',peak:.12*v,dec:.3}))};
function gSnd(k,v=1){if(!GS.on||!GSND[k])return;const now=performance.now();if(now-(GS.last[k]||0)<38)return;GS.last[k]=now;const x=gsCtx();if(!x||x.state!=='running'&&x.state!=='suspended')return;
 try{GSND[k](x,x.currentTime+.005,v)}catch(e){}}
const gBuzz=ms=>{if(GS.on&&navigator.vibrate)try{navigator.vibrate(ms)}catch(e){}};
A.gsnd=t=>{GS.on=!GS.on;store.set('gsnd',GS.on);if(GS.on){gsCtx();gSnd('tap')}const b=t&&t.closest&&t.closest('button');if(b){const s=b.querySelector('.sw');if(s)s.classList.toggle('on',GS.on)}$$('[data-a="gsnd"]').forEach(x=>x.setAttribute('aria-pressed',String(GS.on)))};
