/* ---------- talking at the table ----------
   at an online table (a game of two, joker or domino with friends) the players can talk. the microphone button joins
   the table's voice circle: you hear everyone else in it and they hear you. sound goes straight between the phones (WebRTC),
   only people seated at that table are connected, and leaving the table leaves the circle */
const GV={key:'',ch:null,peers:new Map(),local:null,mute:false,allow:[],here:new Map(),ask:null,ac:null,lv:null,chk:null,busy:false};
/* the table on screen now: its key, who else sits at it, and its own channel for a short "I'm on the mic" note */
function gvWhere(){if(!ME)return null;
 if(S.page&&S.page.id==='jktable'&&typeof JO!=='undefined'&&JO.id&&JO.t&&JO.seat>=0&&JO.t.status!=='closed')return{key:'jk'+JO.id,allow:JO.t.seats.filter(u=>u&&u!==ME.id),ch:JO.ch};
 if(S.page&&S.page.id==='dmtable'&&typeof DMO!=='undefined'&&DMO.id&&DMO.t&&DMO.seat>=0&&DMO.t.status!=='closed')return{key:'dm'+DMO.id,allow:DMO.t.seats.filter(u=>u&&u!==ME.id),ch:DMO.ch};
 if(S.page&&S.page.id==='lotable'&&typeof LOT!=='undefined'&&LOT.id&&LOT.t&&LOT.seat>=0&&LOT.t.status!=='closed')return{key:'lo'+LOT.id,allow:LOT.t.seats.filter(u=>u&&u!==ME.id),ch:LOT.ch};
 if(!S.page&&S.tab==='games'&&S.game){const c=GAME[S.game]&&GAME[S.game].ctx;if(c&&c.mode==='online'&&c.gid&&c.opp&&!c.gone)return{key:'g'+c.gid,allow:[c.opp],ch:c.gr&&c.gr.ch}}
 return null}
const gvOk=u=>!!u&&!!ME&&u!==ME.id&&GV.allow.includes(u);
function gvSend(p){try{if(GV.ch)GV.ch.send({type:'broadcast',event:'sig',payload:Object.assign({from:ME.id},p)})}catch(e){}}
/* the button sits among the table's tools; it says whether the mic is off, on, or muted, and glows when the other side is talking */
function gvDraw(){const w=gvWhere();if(GV.ch&&(!w||w.key!==GV.key)){gvLeave(true);return}
 if(w&&w.ch&&!w.ch.__gv){w.ch.__gv=1;try{w.ch.on('broadcast',{event:'vc'},({payload:d})=>gvHeard(d))}catch(e){}}
 const top=$('.gtop',view);let b=$('.gvb',view);
 if(!w||!top){if(b)b.remove();return}
 if(!b){const at=$('[data-a="g3tog"]',top)||$('[data-a="gmenu"]',top);if(!at)return;b=document.createElement('button');b.className='ibtn gvb';b.dataset.a='gvoice';at.parentNode.insertBefore(b,at)}
 const on=!!GV.ch,lab=on?(GV.mute?'მიკროფონი გამორთულია':'ხმოვანი საუბარი ჩართულია'):'ხმოვანი საუბარი';
 b.classList.toggle('on',on&&!GV.mute);b.classList.toggle('mute',on&&GV.mute);b.classList.toggle('ask',!on&&!!GV.ask&&GV.ask.key===w.key);b.setAttribute('aria-pressed',String(on));b.setAttribute('aria-label',lab);b.title=lab;
 const want=on&&!GV.mute?'mic':'micoff';if(b.dataset.ic!==want){b.dataset.ic=want;b.innerHTML=ic(want)}}
/* someone else at the table switched their microphone on */
function gvHeard(d){const w=gvWhere();if(!d||!w||!d.from||!w.allow.includes(d.from)||GV.ch)return;if(!d.on){if(GV.ask&&GV.ask.from===d.from)GV.ask=null;gvDraw();return}
 const fresh=!GV.ask||GV.ask.from!==d.from||Date.now()-GV.ask.at>60000;GV.ask={key:w.key,from:d.from,at:Date.now()};gvDraw();
 if(fresh)toast(`${String(pname(d.from)).split(' ')[0]} ხმაზეა. დააჭირე მიკროფონს, რომ ისაუბროთ`)}
A.gvoice=()=>{if(!GV.ch){gvJoin();return}
 const ids=[...GV.here.keys()].filter(gvOk);
 sheet(head('ხმოვანი საუბარი')+`<div class="ph-body"><div class="gvlist">${ids.length?ids.map(u=>`<div class="row" data-vu="${u}">${av(u,36)}<span class="grow"><b>${esc(pname(u))}</b><span class="sub">${GV.here.get(u)&&GV.here.get(u).mute?'მიკროფონი გამორთული აქვს':GV.peers.has(u)&&GV.peers.get(u).pc.connectionState==='connected'?'გესმით ერთმანეთის':'კავშირი მყარდება…'}</span></span></div>`).join(''):'<p class="muted">მაგიდასთან ჯერ სხვა არავინაა ხმაზე. როცა ჩაერთვებიან, მათ ხმას აქ გაიგებ.</p>'}</div>
  <div class="gmenu"><button data-a="gvmute" aria-pressed="${GV.mute}">${ic(GV.mute?'micoff':'mic')}<span>${GV.mute?'მიკროფონის ჩართვა':'მიკროფონის გამორთვა'}</span></button><button data-a="gvleave">${ic('hangup')}<span>საუბრიდან გასვლა</span></button></div></div>`,'short')};
A.gvmute=()=>{closeSheet();gvMute(!GV.mute)};
A.gvleave=()=>{closeSheet();gvLeave()};
function gvMute(m){GV.mute=!!m;const t=GV.local&&GV.local.getAudioTracks()[0];if(t)t.enabled=!GV.mute;try{if(GV.ch)GV.ch.track({mute:GV.mute}).catch(()=>{})}catch(e){}gvDraw()}
async function gvJoin(){const w=gvWhere();if(!w||GV.busy)return;
 if(!navigator.mediaDevices||!navigator.mediaDevices.getUserMedia||typeof RTCPeerConnection==='undefined'){toast('ამ ბრაუზერში ხმოვანი საუბარი არ მუშაობს');return}
 GV.busy=true;let st=null;try{st=await navigator.mediaDevices.getUserMedia({audio:{echoCancellation:true,noiseSuppression:true,autoGainControl:true}})}catch(e){toast('მიკროფონზე წვდომა არ მოგვცეს')}finally{GV.busy=false}
 if(!st)return;const w2=gvWhere();if(!w2||w2.key!==w.key){st.getTracks().forEach(t=>t.stop());return}
 if(GV.ch)gvLeave(true);
 Object.assign(GV,{key:w.key,allow:w.allow,local:st,mute:false,ask:null,here:new Map()});
 const ch=GV.ch=sb.channel('gv-'+w.key,{config:{presence:{key:ME.id},broadcast:{self:false}}});
 ch.on('presence',{event:'sync'},gvSync).on('broadcast',{event:'sig'},({payload:m})=>gvSig(m))
  .subscribe(s=>{if(s==='SUBSCRIBED')ch.track({mute:GV.mute}).catch(()=>{})});
 try{if(w.ch)w.ch.send({type:'broadcast',event:'vc',payload:{from:ME.id,on:1}})}catch(e){}
 clearInterval(GV.chk);GV.chk=setInterval(gvDraw,2000);
 if(!GV.unload){GV.unload=()=>gvLeave(true);window.addEventListener('pagehide',GV.unload)}
 gvDraw();toast('ხმოვანი საუბარი ჩაირთო')}
function gvLeave(quiet){const w=gvWhere(),key=GV.key;clearInterval(GV.chk);GV.chk=null;clearInterval(GV.lv);GV.lv=null;
 for(const u of[...GV.peers.keys()])gvClose(u);
 if(GV.local)GV.local.getTracks().forEach(t=>{try{t.stop()}catch(e){}});
 if(GV.ch){try{GV.ch.untrack()}catch(e){}try{sb.removeChannel(GV.ch)}catch(e){}}
 if(w&&w.key===key&&w.ch)try{w.ch.send({type:'broadcast',event:'vc',payload:{from:ME.id,on:0}})}catch(e){}
 Object.assign(GV,{key:'',ch:null,local:null,mute:false,allow:[],here:new Map()});$$('.speaking[data-vu],.pl.speaking').forEach(e=>e.classList.remove('speaking'));
 if(!quiet)toast('ხმოვანი საუბარი დასრულდა');gvDraw()}
/* who is in the circle: the one with the smaller id calls the other, so each pair connects once */
function gvSync(){if(!GV.ch)return;const w=gvWhere();if(w&&w.key===GV.key)GV.allow=w.allow;const ps=GV.ch.presenceState(),now=new Map();
 for(const[k,arr]of Object.entries(ps)){const m=arr&&arr[arr.length-1];if(gvOk(k))now.set(k,m||{})}GV.here=now;
 for(const u of now.keys())if(!GV.peers.has(u)){const p=gvPeer(u);if(ME.id<u)gvOffer(p)}
 for(const u of[...GV.peers.keys()])if(!now.has(u))gvClose(u);gvDraw()}
function gvPeer(u){const pc=new RTCPeerConnection({iceServers:ICE}),p={u,pc,pend:[],au:null,an:null};GV.peers.set(u,p);
 pc.onicecandidate=e=>{if(e.candidate)gvSend({to:u,ice:e.candidate})};
 pc.ontrack=e=>{const s=e.streams&&e.streams[0]||new MediaStream([e.track]);if(!p.au){p.au=new Audio();p.au.autoplay=true;p.au.setAttribute('playsinline','')}if(p.au.srcObject!==s){p.au.srcObject=s;p.au.play().catch(()=>{})}gvLevel(p,s)};
 pc.onconnectionstatechange=()=>{if(pc.connectionState==='failed'){gvClose(u);setTimeout(()=>{if(GV.ch&&GV.here.has(u)&&!GV.peers.has(u)){const n=gvPeer(u);if(ME.id<u)gvOffer(n)}},1500)}};
 return p}
function gvAdd(p){const t=GV.local&&GV.local.getAudioTracks()[0];if(t&&!p.added){try{p.pc.addTrack(t,GV.local);p.added=1}catch(e){}}}
async function gvOffer(p){try{gvAdd(p);const o=await p.pc.createOffer();await p.pc.setLocalDescription(o);gvSend({to:p.u,sdp:{type:o.type,sdp:o.sdp}})}catch(e){}}
const gvSdp=x=>!!x&&(x.type==='offer'||x.type==='answer')&&typeof x.sdp==='string'&&x.sdp.length<20000;
async function gvSig(m){if(!GV.ch||!m||m.to!==ME.id||!gvOk(m.from))return;let p=GV.peers.get(m.from);
 try{if(gvSdp(m.sdp)&&m.sdp.type==='offer'){if(p&&(p.pc.signalingState!=='stable'||p.pc.remoteDescription)){gvClose(m.from);p=null}if(!p)p=gvPeer(m.from);
   await p.pc.setRemoteDescription(m.sdp);gvAdd(p);const a=await p.pc.createAnswer();await p.pc.setLocalDescription(a);gvSend({to:m.from,sdp:{type:a.type,sdp:a.sdp}});p.pend.splice(0).forEach(c=>p.pc.addIceCandidate(c).catch(()=>{}))}
  else if(gvSdp(m.sdp)&&m.sdp.type==='answer'&&p){await p.pc.setRemoteDescription(m.sdp);p.pend.splice(0).forEach(c=>p.pc.addIceCandidate(c).catch(()=>{}))}
  else if(m.ice&&typeof m.ice==='object'&&p){if(p.pc.remoteDescription)p.pc.addIceCandidate(m.ice).catch(()=>{});else if(p.pend.length<60)p.pend.push(m.ice)}}catch(e){}}
function gvClose(u){const p=GV.peers.get(u);if(!p)return;try{p.pc.close()}catch(e){}if(p.au){try{p.au.pause();p.au.srcObject=null}catch(e){}}GV.peers.delete(u);gvSpeak(u,false)}
/* the card of whoever is talking lights up */
function gvLevel(p,s){try{if(!GV.ac)GV.ac=new (window.AudioContext||window.webkitAudioContext)();const tr=s.getAudioTracks()[0];if(!tr||p.an)return;
 const src=GV.ac.createMediaStreamSource(new MediaStream([tr])),an=GV.ac.createAnalyser();an.fftSize=256;src.connect(an);p.an=an;p.buf=new Uint8Array(an.frequencyBinCount);
 if(!GV.lv)GV.lv=setInterval(()=>{GV.peers.forEach(x=>{if(!x.an)return;x.an.getByteFrequencyData(x.buf);let t=0;for(const v of x.buf)t+=v;gvSpeak(x.u,t/x.buf.length>18)})},300)}catch(e){}}
function gvSpeak(u,on){const els=$$(`[data-vu="${u}"]`);const c=S.game&&GAME[S.game]&&GAME[S.game].ctx;if(!S.page&&c&&c.opp===u)els.push(...$$(`.pl[data-side="${-c.side}"]`,view));els.forEach(e=>e.classList.toggle('speaking',!!on))}
/* the button follows every redraw of a table */
{const gv=gview;gview=function(...a){const r=gv.apply(this,a);try{gvDraw()}catch(e){}return r}}
{const jd=joDraw;joDraw=function(...a){const r=jd.apply(this,a);try{gvDraw()}catch(e){}return r}}
{const dd=dmoDraw;dmoDraw=function(...a){const r=dd.apply(this,a);try{gvDraw()}catch(e){}return r}}
{const ld=lotDraw;lotDraw=function(...a){const r=ld.apply(this,a);try{gvDraw()}catch(e){}return r}}
{const lb=A.lobby;A.lobby=function(...a){const r=lb.apply(this,a);if(GV.ch)try{gvDraw()}catch(e){}return r}}
