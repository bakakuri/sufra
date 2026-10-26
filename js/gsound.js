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
 /* two silver-rimmed horns touching: bright, a little out of tune with each other, ringing on */
 horn:(x,t,v)=>{for(const[f,p,d]of[[1870,.07,1.1],[2990,.05,.8],[4430,.035,.55],[6120,.02,.35],[1913,.05,1.2],[3110,.03,.7]])gsTone(x,t,{f,type:'sine',peak:p*v,dec:d});gsNoise(x,t,{f:5200,q:1.4,peak:.09*v,dec:.03})},
 win:(x,t,v)=>{[523,659,784,1047,1319].forEach((f,k)=>{gsTone(x,t+k*.11,{f,type:'triangle',peak:.16*v,dec:.35});gsTone(x,t+k*.11,{f:f*2,type:'sine',peak:.04*v,dec:.25})});gsNoise(x,t+.5,{f:6000,q:.5,type:'highpass',peak:.05*v,a:.05,dec:.8})},
 lose:(x,t,v)=>[392,349,311,262].forEach((f,k)=>gsTone(x,t+k*.16,{f,type:'sine',peak:.13*v,dec:.4})),
 draw:(x,t,v)=>[523,523,659].forEach((f,k)=>gsTone(x,t+k*.14,{f,type:'triangle',peak:.12*v,dec:.3}))};
function gSnd(k,v=1){if(!GS.on||!GSND[k])return;const now=performance.now();if(now-(GS.last[k]||0)<38)return;GS.last[k]=now;const x=gsCtx();if(!x||x.state!=='running'&&x.state!=='suspended')return;
 try{GSND[k](x,x.currentTime+.005,v)}catch(e){}}
const gBuzz=ms=>{if(GS.on&&navigator.vibrate)try{navigator.vibrate(ms)}catch(e){}};
A.gsnd=t=>{GS.on=!GS.on;store.set('gsnd',GS.on);if(GS.on){gsCtx();gSnd('tap')}const b=t&&t.closest&&t.closest('button');if(b){const s=b.querySelector('.sw');if(s)s.classList.toggle('on',GS.on)}$$('[data-a="gsnd"]').forEach(x=>x.setAttribute('aria-pressed',String(GS.on)));if(typeof gAmbStop==='function'){if(GS.on){if(typeof gAmbSync==='function')gAmbSync()}else gAmbStop()}};

/* ---------- the sound of the place: quiet, made in the browser ----------
   a room tone or the air outside; crickets in the evening and birds by day in the yards; now and then glasses touching;
   at the card table and in the yard of an evening, a soft drone in the old three-voice manner (an original tune, low and far off) */
const GAMB={on:store.get('gamb',true),key:null,g:null,src:null,tm:[],lfo:null};
function gAmbStop(){for(const t of GAMB.tm)clearTimeout(t);GAMB.tm=[];const x=GS.ctx;if(GAMB.g&&x){const g=GAMB.g,s=GAMB.src,l=GAMB.lfo;try{g.gain.cancelScheduledValues(x.currentTime);g.gain.setTargetAtTime(0,x.currentTime,.4)}catch(e){}setTimeout(()=>{try{s&&s.stop();l&&l.stop();g.disconnect()}catch(e){}},1600)}GAMB.g=null;GAMB.src=null;GAMB.lfo=null;GAMB.key=null}
function gAmb(kind,time,game){const key=kind?kind+':'+time+':'+game:null;if(key===GAMB.key)return;gAmbStop();if(!kind||!GS.on||!GAMB.on||document.hidden)return;const x=gsCtx();if(!x)return;GAMB.key=key;
 const out=x.createGain();out.gain.value=0;out.connect(GS.bus);out.gain.setTargetAtTime(1,x.currentTime,1.2);GAMB.g=out;
 /* the bed: noise through a filter, very low; outside it breathes like wind */
 const s=x.createBufferSource();s.buffer=GS.noise;s.loop=true;const f=x.createBiquadFilter(),bg=x.createGain();f.type=kind==='out'?'bandpass':'lowpass';f.frequency.value=kind==='out'?520:kind==='desk'?420:300;f.Q.value=kind==='out'?.6:.7;bg.gain.value=kind==='out'?.045:kind==='desk'?.03:.035;
 s.connect(f);f.connect(bg);bg.connect(out);s.start();GAMB.src=s;
 if(kind==='out'){const l=x.createOscillator(),lg=x.createGain();l.frequency.value=.07;lg.gain.value=.02;l.connect(lg);lg.connect(bg.gain);l.start();GAMB.lfo=l}
 const at=(ms,fn)=>{const t=setTimeout(()=>{GAMB.tm=GAMB.tm.filter(v=>v!==t);if(GAMB.key===key&&GS.ctx)try{fn(GS.ctx)}catch(e){}},ms);GAMB.tm.push(t)};
 const tone=(x,t,fq,dur,pk,type='sine',dest=out)=>{const o=x.createOscillator(),g=x.createGain();o.type=type;o.frequency.value=fq;g.gain.setValueAtTime(0,t);g.gain.linearRampToValueAtTime(pk,t+.005);g.gain.exponentialRampToValueAtTime(1e-4,t+dur);o.connect(g);g.connect(dest);o.start(t);o.stop(t+dur+.05)};
 const crickets=()=>{const x=GS.ctx,t=x.currentTime;for(const[fq,dl]of[[4650,0],[4420,.31]])for(let k=0;k<3;k++)tone(x,t+dl+k*.065,fq,.035,.009);at(700+Math.random()*900,crickets)};
 const birds=()=>{const x=GS.ctx,t=x.currentTime,n=2+Math.floor(Math.random()*3);for(let k=0;k<n;k++){const o=x.createOscillator(),g=x.createGain(),t0=t+k*.16;o.frequency.setValueAtTime(2300+Math.random()*500,t0);o.frequency.exponentialRampToValueAtTime(3600+Math.random()*700,t0+.08);
   g.gain.setValueAtTime(0,t0);g.gain.linearRampToValueAtTime(.012,t0+.01);g.gain.exponentialRampToValueAtTime(1e-4,t0+.1);o.connect(g);g.connect(out);o.start(t0);o.stop(t0+.12)}at(3500+Math.random()*6000,birds)};
 const clink=()=>{const x=GS.ctx,t=x.currentTime;for(const[fq,d]of[[2760,0],[4180,0],[3320,.09],[5010,.09]])tone(x,t+d,fq,.7,.008);at(18000+Math.random()*22000,clink)};
 const page=()=>{const x=GS.ctx,t=x.currentTime,b=x.createBufferSource(),fl=x.createBiquadFilter(),g=x.createGain();b.buffer=GS.noise;fl.type='bandpass';fl.frequency.setValueAtTime(1800,t);fl.frequency.linearRampToValueAtTime(3400,t+.35);g.gain.setValueAtTime(0,t);g.gain.linearRampToValueAtTime(.02,t+.08);g.gain.linearRampToValueAtTime(0,t+.42);b.connect(fl);fl.connect(g);g.connect(out);b.start(t);b.stop(t+.5);at(25000+Math.random()*30000,page)};
 /* the drone: a low D with its fifth held under a middle voice that steps and returns, the top voice a fourth or fifth above it */
 const drone=()=>{const x=GS.ctx,t=x.currentTime+.1,L=14,lp=x.createBiquadFilter(),dg=x.createGain();lp.type='lowpass';lp.frequency.value=900;dg.gain.setValueAtTime(0,t);dg.gain.linearRampToValueAtTime(.022,t+3);dg.gain.setValueAtTime(.022,t+L-3);dg.gain.linearRampToValueAtTime(0,t+L);lp.connect(dg);dg.connect(out);
  const v=(fq,t0,t1,type)=>{const o=x.createOscillator(),vb=x.createOscillator(),vg=x.createGain();o.type=type||'triangle';o.frequency.value=fq;vb.frequency.value=4.6+Math.random();vg.gain.value=fq*.006;vb.connect(vg);vg.connect(o.frequency);const g=x.createGain();g.gain.setValueAtTime(0,t0);g.gain.linearRampToValueAtTime(.33,t0+.6);g.gain.setValueAtTime(.33,t1-.5);g.gain.linearRampToValueAtTime(0,t1);o.connect(g);g.connect(lp);o.start(t0);vb.start(t0);o.stop(t1+.05);vb.stop(t1+.05)};
  v(73.4,t,t+L,'sine');v(110,t,t+L,'sine');const mid=[146.8,164.8,174.6,164.8,146.8,164.8,146.8],top=[220,246.9,261.6,246.9,220,220,196];const st=L/mid.length;mid.forEach((fq,k)=>{v(fq,t+k*st,t+(k+1)*st+.3);v(top[k],t+k*st+.15,t+(k+1)*st+.3)});at(60000+Math.random()*40000,drone)};
 /* a watch: when the table leaves the screen (2D, another tab, the page closed) the sound goes with it */
 const watch=()=>{const cv=typeof G3D!=='undefined'&&G3D.cv;if(!cv||!cv.isConnected){gAmbStop();return}at(2000,watch)};at(2000,watch);
 if(kind==='out'){if(time==='eve')at(400,crickets);else at(1500,birds)}if(kind==='room'||(kind==='out'&&game==='domino'&&time==='eve'))at(9000,clink);if(kind==='desk')at(12000,page);
 if((kind==='room'&&time==='eve')||(game==='domino'&&time==='eve'))at(5000,drone)}
document.addEventListener('visibilitychange',()=>{if(document.hidden)gAmbStop();else if(typeof gAmbSync==='function')gAmbSync()});
