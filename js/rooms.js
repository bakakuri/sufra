/* live rooms: virtual supra with a tamada (video, up to 8) and birja voice rooms (up to 12), WebRTC mesh over realtime */
const ROOM_TOPICS=[['city','ქალაქი'],['sport','სპორტი'],['politics','პოლიტიკა'],['games','თამაშები'],['music','მუსიკა'],['tech','ტექნოლოგიები'],['love','ურთიერთობები'],['other','სხვა']];
const TOASTS=['ღმერთის და მშვიდობის','სამშობლოს, საქართველოს','მასპინძლის და ამ ოჯახის','მშობლების','შენდობა: ვინც ჩვენ შორის აღარ არის','მეგობრობის','სიყვარულის და ქალების','ბავშვების და მომავლის','სტუმრების','ერთმანეთის, ალავერდით'];
const ROOM_CAP={supra:8,birja:12};
const topicName=k=>(ROOM_TOPICS.find(t=>t[0]===k)||ROOM_TOPICS[7])[1];
let ROOM=null;

PG.rooms={r(kind){S.rkind=kind==='birja'?'birja':S.rkind||'supra';
 view.innerHTML=pgHead('ოთახები',`<button class="btn sm" data-a="newroom">${ic('plus')}ახალი</button>`)+`<div class="seg" role="group" aria-label="ოთახის ტიპი">${[['supra','ვირტუალური სუფრა'],['birja','ბირჟა']].map(([k,l])=>`<button data-a="rkind" data-k="${k}" aria-pressed="${S.rkind===k}">${l}</button>`).join('')}</div>
 <p class="hint" id="rhint"></p><div id="rlist">${skel(2)}</div>`;loadRooms()}};
A.rkind=t=>{S.rkind=t.dataset.k;$$('[data-a="rkind"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)));loadRooms()};
async function loadRooms(){const el=$('#rlist'),k=S.rkind;if(!el)return;
 $('#rhint').textContent=k==='supra'?'ვიდეო-სუფრა მეგობრებთან, 8 ადამიანამდე. თამადა სადღეგრძელოებს რიგით ამბობს, სხვები ჭიქებს უჭახუნებენ.':'ხმოვანი ოთახი თემაზე, 12 ადამიანამდე. ლაპარაკისთვის აწიე ხელი, მასპინძელი სიტყვას მოგცემს.';
 try{const rows=await q(sb.from('rooms').select('id,host,kind,title,topic,is_private,created_at').eq('live',true).eq('kind',k).gt('created_at',new Date(Date.now()-12*36e5).toISOString()).order('created_at',{ascending:false}).limit(40));
  await loadProfiles(rows.map(r=>r.host));if(!el.isConnected)return;
  el.innerHTML=rows.length?`<div class="list">${rows.map(r=>`<button class="row roomrow" data-a="page" data-p="room" data-arg="${r.id}"><span class="rico ${r.kind}">${ic(r.kind==='supra'?'wine':'mic')}</span><span class="grow"><b>${esc(r.title)}</b><span class="sub">${r.kind==='birja'?topicName(r.topic)+' · ':''}${esc(pname(r.host))} · ${ago(r.created_at)}${r.is_private?' · მეგობრებისთვის':''}</span></span><span class="live"><i></i>ცოცხლად</span></button>`).join('')}</div>`
   :empty(k==='supra'?'ახლა სუფრა არავის აქვს გაშლილი':'ბირჟაზე ახლა არავინაა','გახსენი პირველმა და მოიწვიე მეგობრები.',`<button class="btn" data-a="newroom">${ic('plus')}${k==='supra'?'სუფრის გაშლა':'ოთახის გახსნა'}</button>`);staggerIn($$('.row',el).slice(0,8))}
 catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
A.newroom=()=>{const k=S.rkind||'supra';sheet(head(k==='supra'?'სუფრის გაშლა':'ბირჟაზე ოთახი')+`<form class="ph-body" id="nrf">
 <div class="seg flat" role="group" aria-label="ტიპი" style="margin:0">${[['supra','ვირტუალური სუფრა'],['birja','ბირჟა']].map(([x,l])=>`<button type="button" data-rk="${x}" aria-pressed="${x===k}">${l}</button>`).join('')}</div>
 <label class="fld">სახელი<input id="nr_t" maxlength="80" required placeholder="${k==='supra'?'მაგ. ნინოს დაბადების დღე':'მაგ. ვინ მოიგებს ლიგას?'}"></label>
 <div class="fld" id="nr_topic"${k==='supra'?' hidden':''}>თემა<div class="chips pick6">${ROOM_TOPICS.map(([x,l],i)=>`<button type="button" data-tp="${x}" aria-pressed="${i===0}">${l}</button>`).join('')}</div></div>
 <label class="chk" id="nr_pw"${k==='birja'?' hidden':''}><input type="checkbox" id="nr_p"><span>მხოლოდ მეგობრებისთვის</span></label>
 <p class="note">${k==='supra'?'შენ იქნები თამადა. კამერა და მიკროფონი ჩაირთვება შესვლისას.':'შენ იქნები მასპინძელი და პირველი მოლაპარაკე.'}</p></form>
 <div class="ph-foot"><span class="sp"></span><button class="btn" id="nr_ok">${ic('live')}გახსნა</button></div>`,'short');
 let kind=k,topic='city';
 $$('[data-rk]').forEach(b=>b.onclick=()=>{kind=b.dataset.rk;$$('[data-rk]').forEach(z=>z.setAttribute('aria-pressed',String(z===b)));$('#nr_topic').hidden=kind==='supra';$('#nr_pw').hidden=kind==='birja'});
 $$('[data-tp]').forEach(b=>b.onclick=()=>{topic=b.dataset.tp;$$('[data-tp]').forEach(z=>z.setAttribute('aria-pressed',String(z===b)))});
 $('#nr_ok').onclick=async()=>{const t=$('#nr_t').value.trim();if(t.length<2){toast('ჩაწერე სახელი');return}const b=$('#nr_ok');b.disabled=true;
  try{const r=await q(sb.from('rooms').insert({host:ME.id,kind,title:t,topic:kind==='birja'?topic:'other',is_private:kind==='supra'&&$('#nr_p').checked}).select('id').single());closeSheet();openPage('room',r.id,['rooms'])}catch(e){toast(errMsg(e));b.disabled=false}}};

/* the room itself */
PG.room={cls:'is-room',r(id){id=+id;view.innerHTML=pgHead('ოთახი')+`<div id="roomb">${skel(1)}</div>`;openRoom(id)}};
async function openRoom(id){let r;try{r=await q(sb.from('rooms').select('*').eq('id',id).maybeSingle())}catch(e){}
 const el=$('#roomb');if(!el)return;
 if(!r||!r.live){el.innerHTML=empty('ოთახი დაიხურა','ეს სუფრა ან საუბარი უკვე დასრულდა.',`<button class="btn" data-a="page" data-p="rooms">სხვა ოთახები</button>`);return}
 await loadProfiles([r.host]);const isHost=r.host===ME.id,supra=r.kind==='supra';
 const h=$('.pghead h2');if(h)h.textContent=r.title;
 $('.pghead').insertAdjacentHTML('beforeend',`<button class="ibtn" data-a="roominvite" aria-label="მოწვევა">${ic('users')}</button><button class="ibtn" data-a="roomshare" aria-label="გაზიარება">${ic('share')}</button>`);
 el.innerHTML=supra?`<div class="tamada" id="tam"></div><div class="rgrid" id="rgrid"></div>
  <div class="rbar"><button class="rbtn" id="rb_mic" aria-pressed="true" aria-label="მიკროფონი">${ic('mic')}</button><button class="rbtn" id="rb_cam" aria-pressed="true" aria-label="კამერა">${ic('video')}</button><button class="rbtn clink" data-a="clink" aria-label="ჭიქის მიჭახუნება">🥂</button><button class="rbtn end" data-a="leaveroom" aria-label="${isHost?'სუფრის დასრულება':'გასვლა'}">${ic('hangup')}</button></div>
  ${isHost?`<section class="tampanel"><h3 class="sec2" style="padding:0 0 6px">თამადის პულტი</h3><div class="row2" style="justify-content:flex-start"><button class="btn sm" data-a="tnext">${ic('wine')}შემდეგი სადღეგრძელო</button><button class="btn sm ghost" data-a="tlist">სიიდან არჩევა</button><button class="btn sm ghost" data-a="tfloor">ალავერდი</button></div><form id="tcf" class="tcustom"><input class="field" id="tci" maxlength="120" placeholder="საკუთარი სადღეგრძელო…" autocomplete="off"><button class="btn sm">თქმა</button></form></section>`:''}`
 :`<div class="topicbar">${ic('mic')}<span>${esc(topicName(r.topic))}</span><span class="sp"></span><span class="muted" id="rcount"></span></div>
  <h3 class="sec2">ლაპარაკობენ</h3><div class="spk" id="spk"></div><h3 class="sec2">უსმენენ</h3><div class="lst" id="lst"></div>
  <div class="rbar"><button class="rbtn" id="rb_mic" aria-pressed="false" aria-label="მიკროფონი">${ic('micoff')}</button><button class="rbtn" id="rb_hand" aria-label="ხელის აწევა">✋</button><button class="rbtn end" data-a="leaveroom" aria-label="${isHost?'ოთახის დახურვა':'გასვლა'}">${ic('hangup')}</button></div>
  ${isHost?'<section class="tampanel" id="hands" hidden></section>':''}`;
 ROOM={id,room:r,isHost,supra,peers:new Map(),present:new Map(),local:null,mic:false,cam:false,st:{toast:-1,custom:'',floor:null,speakers:[r.host],hands:[]},ch:null,ac:null,levels:null,full:false};
 S.chanCleanup=()=>leaveRoom(false);
 if(supra){try{ROOM.local=await navigator.mediaDevices.getUserMedia({audio:{echoCancellation:true,noiseSuppression:true},video:{facingMode:'user',width:{ideal:480},height:{ideal:640}}});ROOM.mic=ROOM.cam=true}catch(e){toast('კამერაზე ან მიკროფონზე წვდომა არ არის. სუფრას მხოლოდ უყურებ');$('#rb_mic').disabled=$('#rb_cam').disabled=true}}
 else if(isHost)await roomMic(true);
 bindRoomControls();roomJoin();drawRoom()}
async function roomMic(on){if(!ROOM)return;
 if(on&&!ROOM.local?.getAudioTracks().length){try{const s=await navigator.mediaDevices.getUserMedia({audio:{echoCancellation:true,noiseSuppression:true}});ROOM.local=ROOM.local||new MediaStream();s.getAudioTracks().forEach(t=>ROOM.local.addTrack(t))}catch(e){toast('მიკროფონზე წვდომა არ არის');return}}
 const tr=ROOM.local?.getAudioTracks()[0];if(tr)tr.enabled=on;ROOM.mic=on&&!!tr;
 ROOM.peers.forEach(p=>{const s=p.audioSender;if(s)s.replaceTrack(ROOM.mic||ROOM.supra?tr||null:null).catch(()=>{})});
 const b=$('#rb_mic');if(b){b.setAttribute('aria-pressed',String(ROOM.mic));b.innerHTML=ic(ROOM.mic?'mic':'micoff')}track()}
function bindRoomControls(){const mic=$('#rb_mic'),cam=$('#rb_cam'),hand=$('#rb_hand');
 if(mic)mic.onclick=()=>{if(!ROOM.supra&&!ROOM.st.speakers.includes(ME.id)){toast('ჯერ აწიე ხელი, მასპინძელი სიტყვას მოგცემს');return}roomMic(!ROOM.mic)};
 if(cam)cam.onclick=()=>{const tr=ROOM.local?.getVideoTracks()[0];if(!tr)return;ROOM.cam=!ROOM.cam;tr.enabled=ROOM.cam;cam.setAttribute('aria-pressed',String(ROOM.cam));cam.innerHTML=ic(ROOM.cam?'video':'block');track();drawRoom()};
 if(hand)hand.onclick=()=>{if(ROOM.st.speakers.includes(ME.id)){toast('უკვე ლაპარაკობ');return}roomSend('hand',{up:true});hand.classList.add('on');toast('ხელი აწიე. მასპინძელი გნახავს')};
 const f=$('#tcf');if(f)f.onsubmit=e=>{e.preventDefault();const v=$('#tci').value.trim();if(!v)return;$('#tci').value='';setRoomState({custom:v,toast:-1,floor:null})}}
function roomJoin(){const ch=ROOM.ch=sb.channel('room-'+ROOM.id,{config:{presence:{key:ME.id},broadcast:{self:false}}});
 ch.on('presence',{event:'sync'},()=>onRoomPresence())
  .on('broadcast',{event:'sig'},({payload:p})=>{if(p&&p.to===ME.id)onRoomSig(p)})
  .on('broadcast',{event:'state'},({payload:p})=>{if(p&&p.from===ROOM.room.host){const was=ROOM.st.speakers.includes(ME.id);ROOM.st=p.st;if(!ROOM.supra&&!was&&ROOM.st.speakers.includes(ME.id))toast('მასპინძელმა სიტყვა მოგცა. ჩართე მიკროფონი');drawRoom();applySpeaker()}})
  .on('broadcast',{event:'hello'},({payload:p})=>{if(ROOM.isHost)roomSend('state',{st:ROOM.st})})
  .on('broadcast',{event:'clink'},({payload:p})=>clinkFx(p.from))
  .on('broadcast',{event:'hand'},({payload:p})=>{if(ROOM.isHost&&p.from){const h=new Set(ROOM.st.hands);p.up?h.add(p.from):h.delete(p.from);setRoomState({hands:[...h]})}})
  .on('broadcast',{event:'end'},()=>{toast(ROOM.supra?'თამადამ სუფრა დაასრულა':'მასპინძელმა ოთახი დახურა');leaveRoom(false);rp()})
  .subscribe(st=>{if(st==='SUBSCRIBED'){track();roomSend('hello',{})}});
 ROOM.onUnload=()=>leaveRoom(false);window.addEventListener('pagehide',ROOM.onUnload)}
function track(){if(ROOM&&ROOM.ch)ROOM.ch.track({n:ME.name,h:ME.hue,a:ME.avatar_url||'',mic:ROOM.mic,cam:ROOM.cam,host:ROOM.isHost}).catch(()=>{})}
function roomSend(event,payload){if(ROOM&&ROOM.ch)ROOM.ch.send({type:'broadcast',event,payload:Object.assign({from:ME.id},payload)})}
function setRoomState(patch){if(!ROOM||!ROOM.isHost)return;Object.assign(ROOM.st,patch);roomSend('state',{st:ROOM.st});drawRoom();applySpeaker()}
function onRoomPresence(){if(!ROOM)return;const st=ROOM.ch.presenceState(),now=new Map();
 for(const[k,arr]of Object.entries(st)){const m=arr[arr.length-1];if(m)now.set(k,m)}
 if(!ROOM.joinedOnce){ROOM.joinedOnce=true;const others=[...now.keys()].filter(k=>k!==ME.id).length;if(others>=ROOM_CAP[ROOM.room.kind]){ROOM.full=true;toast('ოთახი სავსეა');leaveRoom(false);const el=$('#roomb');if(el)el.innerHTML=empty('ოთახი სავსეა',`აქ უკვე ${others} ადამიანია. სცადე ცოტა ხანში.`,'<button class="btn" data-a="page" data-p="rooms">სხვა ოთახები</button>');return}}
 now.forEach((m,k)=>{if(m&&m.n&&!PC.has(k)&&k!==ME.id)PC.set(k,{id:k,name:m.n,hue:m.h,avatar_url:m.a||null})});
 ROOM.present=now;
 for(const k of now.keys())if(k!==ME.id&&!ROOM.peers.has(k)){const p=newRoomPeer(k);if(ME.id<k)roomOffer(p)}
 for(const k of [...ROOM.peers.keys()])if(!now.has(k))closePeer(k);
 if(ROOM.isHost&&ROOM.st.hands.some(h=>!now.has(h)))setRoomState({hands:ROOM.st.hands.filter(h=>now.has(h))});
 drawRoom()}
function newRoomPeer(uid){const pc=new RTCPeerConnection({iceServers:ICE}),p={uid,pc,stream:new MediaStream(),pendingIce:[]};ROOM.peers.set(uid,p);
 pc.onicecandidate=e=>{if(e.candidate)roomSend('sig',{to:uid,ice:e.candidate})};
 pc.ontrack=e=>{p.stream.addTrack(e.track);e.track.onunmute=()=>drawRoom();attachPeer(p);watchLevel(p)};
 pc.onconnectionstatechange=()=>{if(pc.connectionState==='failed'){closePeer(uid);setTimeout(()=>{if(ROOM&&ROOM.present.has(uid)&&!ROOM.peers.has(uid)){const n=newRoomPeer(uid);if(ME.id<uid)roomOffer(n)}},1500)}};
 return p}
function addLocal(p,fromOffer){const pc=p.pc,a=ROOM.local?.getAudioTracks()[0]||null,v=ROOM.local?.getVideoTracks()[0]||null;
 if(fromOffer){pc.getTransceivers().forEach(t=>{const kind=t.receiver.track.kind;t.direction='sendrecv';if(kind==='audio'){p.audioSender=t.sender;t.sender.replaceTrack(ROOM.supra||ROOM.mic?a:null)}else{t.sender.replaceTrack(v)}});return}
 const ta=pc.addTransceiver('audio',{direction:'sendrecv'});p.audioSender=ta.sender;ta.sender.replaceTrack(ROOM.supra||ROOM.mic?a:null);
 if(ROOM.supra){const tv=pc.addTransceiver('video',{direction:'sendrecv'});tv.sender.replaceTrack(v)}}
async function roomOffer(p){try{addLocal(p,false);const o=await p.pc.createOffer();await p.pc.setLocalDescription(o);roomSend('sig',{to:p.uid,sdp:o})}catch(e){}}
async function onRoomSig(m){if(!ROOM)return;let p=ROOM.peers.get(m.from);
 try{if(m.sdp&&m.sdp.type==='offer'){if(p&&(p.pc.signalingState!=='stable'||p.pc.remoteDescription)){closePeer(m.from);p=null}if(!p)p=newRoomPeer(m.from);await p.pc.setRemoteDescription(m.sdp);addLocal(p,true);const a=await p.pc.createAnswer();await p.pc.setLocalDescription(a);roomSend('sig',{to:m.from,sdp:a});p.pendingIce.splice(0).forEach(c=>p.pc.addIceCandidate(c).catch(()=>{}))}
  else if(m.sdp&&m.sdp.type==='answer'&&p){await p.pc.setRemoteDescription(m.sdp);p.pendingIce.splice(0).forEach(c=>p.pc.addIceCandidate(c).catch(()=>{}))}
  else if(m.ice&&p){if(p.pc.remoteDescription)p.pc.addIceCandidate(m.ice).catch(()=>{});else p.pendingIce.push(m.ice)}}catch(e){}}
function closePeer(uid){const p=ROOM&&ROOM.peers.get(uid);if(!p)return;try{p.pc.close()}catch(e){}ROOM.peers.delete(uid);drawRoom()}
function attachPeer(p){const el=document.getElementById('rv-'+p.uid);if(el&&el.srcObject!==p.stream){el.srcObject=p.stream;el.play?.().catch(()=>{})}}
function applySpeaker(){if(!ROOM||ROOM.supra)return;const me=ROOM.st.speakers.includes(ME.id);if(!me&&ROOM.mic)roomMic(false);const h=$('#rb_hand');if(h&&me)h.classList.remove('on')}
function watchLevel(p){try{if(!ROOM.ac)ROOM.ac=new (window.AudioContext||window.webkitAudioContext)();const tr=p.stream.getAudioTracks()[0];if(!tr||p.an)return;
 const src=ROOM.ac.createMediaStreamSource(new MediaStream([tr])),an=ROOM.ac.createAnalyser();an.fftSize=256;src.connect(an);p.an=an;p.buf=new Uint8Array(an.frequencyBinCount);
 if(!ROOM.levels)ROOM.levels=setInterval(()=>{if(!ROOM){return}ROOM.peers.forEach(x=>{if(!x.an)return;x.an.getByteFrequencyData(x.buf);let s=0;for(const v of x.buf)s+=v;const on=s/x.buf.length>18;const t=document.querySelector(`[data-tile="${x.uid}"]`);if(t)t.classList.toggle('speaking',on)})},300)}catch(e){}}
function tileHTML(uid,me){const m=me?{n:ME.name,mic:ROOM.mic,cam:ROOM.cam,host:ROOM.isHost}:ROOM.present.get(uid)||{},p=prof(uid),floor=ROOM.st.floor===uid,host=uid===ROOM.room.host;
 if(!ROOM.supra)return `<div class="ptile${floor?' floor':''}" data-tile="${uid}"><span class="pav">${av(uid,64)}${me?'':`<audio id="rv-${uid}" autoplay></audio>`}</span><b>${esc(String(p.name||m.n||'').split(' ')[0])}${host?' 👑':''}</b><span class="pmic">${ic(m.mic?'mic':'micoff')}</span></div>`;
 return `<div class="vtile${floor?' floor':''}" data-tile="${uid}"><video id="${me?'rv-me':'rv-'+uid}" autoplay playsinline${me?' muted':''}></video>${(me?ROOM.cam:m.cam!==false)?'':`<span class="vav">${av(uid,72)}</span>`}<span class="vname">${host?'🍷 ':''}${esc(String(p.name||m.n||'').split(' ')[0])}${me?' (შენ)':''}${m.mic===false?` ${ic('micoff')}`:''}</span>${floor?'<span class="vfloor">სიტყვა აქვს</span>':''}</div>`}
function drawRoom(){if(!ROOM)return;const ids=[ME.id,...[...ROOM.present.keys()].filter(k=>k!==ME.id)];
 const sig=JSON.stringify([ids,ids.map(u=>{const m=u===ME.id?{mic:ROOM.mic,cam:ROOM.cam}:ROOM.present.get(u)||{};return [m.mic,m.cam,!!PC.get(u)]}),ROOM.st.floor,ROOM.st.speakers]),fresh=sig!==ROOM.sig;ROOM.sig=sig;
 if(ROOM.supra){const g=$('#rgrid');if(!g)return;if(fresh||!g.childElementCount){g.dataset.n=Math.min(ids.length,8);g.innerHTML=ids.map(u=>tileHTML(u,u===ME.id)).join('')}
  const lv=$('#rv-me');if(lv&&ROOM.local&&lv.srcObject!==ROOM.local){lv.srcObject=ROOM.local}ROOM.peers.forEach(attachPeer);
  const t=$('#tam'),st=ROOM.st;if(t)t.innerHTML=`<span class="tam-ic">🍷</span><div class="grow"><span class="eyebrow">თამადა · ${esc(pname(ROOM.room.host))}</span><b>${st.custom?esc(st.custom):st.toast>=0?'გაუმარჯოს '+esc(TOASTS[st.toast])+'!':'სუფრა იწყება…'}</b>${st.floor?`<span class="sub">ალავერდი: ${esc(pname(st.floor))}</span>`:''}</div>`}
 else{const sp=$('#spk'),ls=$('#lst');if(!sp)return;const speakers=ids.filter(u=>ROOM.st.speakers.includes(u)),listeners=ids.filter(u=>!ROOM.st.speakers.includes(u));
  if(fresh||!sp.childElementCount){sp.innerHTML=speakers.map(u=>tileHTML(u,u===ME.id)).join('')||'<p class="muted">ჯერ არავინ</p>';ls.innerHTML=listeners.map(u=>tileHTML(u,u===ME.id)).join('')||'<p class="muted">ჯერ არავინ</p>'}
  ROOM.peers.forEach(attachPeer);const c=$('#rcount');if(c)c.textContent=ids.length+' ოთახში';
  const hs=$('#hands');if(hs){const hands=ROOM.st.hands.filter(h=>ROOM.present.has(h));hs.hidden=!hands.length&&ROOM.st.speakers.length<2;
   hs.innerHTML=`<h3 class="sec2" style="padding:0 0 6px">მასპინძლის პულტი</h3>${hands.map(h=>`<div class="row">${av(h,36)}<span class="grow"><b>${esc(pname(h))}</b><span class="sub">✋ ხელი აწია</span></span><button class="btn sm" data-a="rspeak" data-u="${h}">სიტყვა</button></div>`).join('')}${ROOM.st.speakers.filter(s=>s!==ME.id).map(s=>`<div class="row">${av(s,36)}<span class="grow"><b>${esc(pname(s))}</b><span class="sub">ლაპარაკობს</span></span><button class="btn sm ghost" data-a="runspeak" data-u="${s}">მსმენელად</button></div>`).join('')}`}}}
A.rspeak=t=>{const u=t.dataset.u;setRoomState({speakers:[...new Set([...ROOM.st.speakers,u])],hands:ROOM.st.hands.filter(h=>h!==u)})};
A.runspeak=t=>{const u=t.dataset.u;setRoomState({speakers:ROOM.st.speakers.filter(s=>s!==u)})};
A.tnext=()=>setRoomState({toast:(ROOM.st.toast+1)%TOASTS.length,custom:'',floor:null});
A.tlist=()=>sheet(head('სადღეგრძელოები')+`<div class="reasons">${TOASTS.map((x,i)=>`<button data-a="tpick" data-i="${i}">${i+1}. ${x}</button>`).join('')}</div>`,'short');
A.tpick=t=>{closeSheet();setRoomState({toast:+t.dataset.i,custom:'',floor:null})};
A.tfloor=()=>{const ids=[...ROOM.present.keys()].filter(k=>k!==ME.id);if(!ids.length){toast('ჯერ სხვა არავინაა სუფრასთან');return}
 sheet(head('ალავერდი ვის?')+`<div class="ph-body">${ids.map(u=>`<button class="row" data-a="tfl" data-u="${u}">${av(u,40)}<span class="grow"><b>${esc(pname(u))}</b></span></button>`).join('')}<button class="row" data-a="tfl" data-u=""><span class="av" style="--s:40px;--h:330">🍷</span><span class="grow"><b>სიტყვა ისევ თამადას</b></span></button></div>`,'short')};
A.tfl=t=>{closeSheet();setRoomState({floor:t.dataset.u||null})};
A.clink=()=>{roomSend('clink',{});clinkFx(ME.id)};
function clinkFx(from){const fx=document.createElement('div');fx.className='clinkfx';fx.innerHTML=`<span>🥂</span><b>გაუმარჯოს!</b><small>${esc(pname(from))}</small>`;document.body.appendChild(fx);setTimeout(()=>fx.remove(),1700);
 try{const ac=ROOM?.ac||(ROOM&&(ROOM.ac=new (window.AudioContext||window.webkitAudioContext)()));if(!ac)return;[2093,3136].forEach((f,i)=>{const o=ac.createOscillator(),g=ac.createGain();o.type='sine';o.frequency.value=f;g.gain.setValueAtTime(.12,ac.currentTime+i*.06);g.gain.exponentialRampToValueAtTime(.0001,ac.currentTime+i*.06+.9);o.connect(g).connect(ac.destination);o.start(ac.currentTime+i*.06);o.stop(ac.currentTime+1.1)})}catch(e){}
 const t=document.querySelector(`[data-tile="${from}"]`);if(t)pop(t)}
A.leaveroom=()=>{if(ROOM&&ROOM.isHost){confirmSheet(ROOM.supra?'სუფრის დასრულება':'ოთახის დახურვა','ყველა გავა ოთახიდან.','დასრულება',async()=>{leaveRoom(true);openPage('rooms')},true)}else{leaveRoom(false);openPage('rooms')}};
function leaveRoom(end){const R_=ROOM;if(!R_)return;ROOM=null;S.chanCleanup=null;
 if(R_.isHost&&(end||!R_.full)){try{R_.ch&&R_.ch.send({type:'broadcast',event:'end',payload:{from:ME.id}})}catch(e){}sb.from('rooms').update({live:false,ended_at:new Date().toISOString()}).eq('id',R_.id).then(()=>{})}
 R_.peers.forEach(p=>{try{p.pc.close()}catch(e){}});R_.local&&R_.local.getTracks().forEach(t=>t.stop());clearInterval(R_.levels);try{R_.ac&&R_.ac.close()}catch(e){}
 if(R_.ch){try{R_.ch.untrack()}catch(e){}sb.removeChannel(R_.ch)}if(R_.onUnload)window.removeEventListener('pagehide',R_.onUnload)}
A.roominvite=()=>{if(!ROOM)return;friendPicker('მოწვევა','მოწვევა',async sel=>{const n=await rpc('invite_to_room',{p_room:ROOM.id,p_users:sel});closeSheet();toast(n?`მოწვევა გაეგზავნა ${n} მეგობარს`:'მოწვევა ვერ გაიგზავნა')})};
A.roomshare=()=>{if(ROOM)shareLink(location.origin+'/#room-'+ROOM.id,ROOM.room.title)};
