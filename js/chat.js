/* messenger: conversations, realtime chat, group chats, voice and photo messages, calls */
let CONVS=[],STREAK=new Map();
async function loadStreaks(){try{const r=await rpc('dm_streaks');STREAK=new Map(r.map(x=>[x.conv_id,x.streak]))}catch(e){}}
const fire=cid=>STREAK.get(cid)?`<span class="fire" title="${STREAK.get(cid)} დღე ზედიზედ">🔥${STREAK.get(cid)}</span>`:'';
async function openChats(){sheet(head('მიმოწერა',`<button class="btn sm ghost" data-a="newgroupchat">${ic('users')}ჯგუფი</button>`)+`<div class="ph-body" id="chl">${skel(4)}</div>`);
 try{[CONVS]=await Promise.all([rpc('my_conversations'),loadStreaks()]);await loadProfiles(CONVS.flatMap(c=>c.members||[]));const el=$('#chl');if(!el)return;
  el.innerHTML=CONVS.map(c=>{const other=!c.is_group&&c.members?.[0],title=c.is_group?(c.title||'ჯგუფი'):pname(other),last=c.last_kind==='voice'?'🎤 ხმოვანი':c.last_kind==='image'?'📷 ფოტო':c.last_body||'';
   return `<button class="row" data-a="chat" data-c="${c.conv_id}">${c.is_group?`<span class="av gav" style="--s:48px;--h:${(c.conv_id*47)%360}">${ic('users')}</span>`:av(other,48)}<span class="grow"><b>${esc(title)}${other?vb(other):''}${fire(c.conv_id)}</b><span class="sub">${c.last_sender===ME.id?'შენ: ':''}${esc(last)} · ${ago(c.last_message_at)}</span></span>${c.unread?`<span class="badge">${c.unread}</span>`:other&&isOnline(other)?'<i class="ond" aria-label="ონლაინ"></i>':''}</button>`}).join('')||empty('მიმოწერა ჯერ ცარიელია','მეგობრის პროფილზე დააჭირე „მიწერა“.','<button class="btn" data-a="page" data-p="friends">მეგობრები</button>')}catch(e){const el=$('#chl');if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
A.chats=()=>openChats();
A.chat=t=>openChat(+t.dataset.c);
A.chatwith=t=>openChatWith(t.dataset.u);
async function openChatWith(uid,draft){try{const c=await rpc('start_dm',{other:uid});openChat(c,draft)}catch(e){toast(errMsg(e))}}
function msgHTML(m){const me=m.sender===ME.id,u=prof(m.sender);let body;
 if(m.kind==='system')return `<div class="sysmsg">${esc(m.body)}</div>`;
 if(m.kind==='voice'&&m.media?.url)body=`<div class="bubble vmsg${me?' me':''}"><audio controls preload="metadata" src="${esc(m.media.url)}"></audio><span>${m.media.dur?m.media.dur+' წმ':'ხმოვანი'}</span></div>`;
 else if(m.kind==='image'&&m.media?.url)body=`<div class="bubble img${me?' me':''}"><img src="${esc(m.media.url)}" alt="" loading="lazy" data-a="imgview" data-src="${esc(m.media.url)}"></div>`;
 else if(m.media?.sticker)body=`<div class="stkmsg">${stickerSVG(m.media.sticker)}</div>`;
 else body=(me?`<div class="bubble me">${linkify(m.body)}</div>`:tx(m.body,'bubble'))+(m.media?.link?linkCard(m.media.link,'inchat'):'');
 return `<div class="mrow${me?' me':''}" data-mid="${m.id}">${!me&&S.chatGroup?`<button class="mav" data-a="user" data-u="${m.sender}" aria-label="${esc(u.name)}">${av(u,26)}</button>`:''}<div class="mcol">${!me&&S.chatGroup?`<span class="mname">${esc(String(u.name).split(' ')[0])}</span>`:''}${body}<span class="mtime">${new Date(m.created_at).toLocaleTimeString('ka-GE',{hour:'2-digit',minute:'2-digit'})}</span></div></div>`}
async function openChat(cid,draft=''){let conv=CONVS.find(c=>c.conv_id===cid);
 try{if(!conv){CONVS=await rpc('my_conversations');conv=CONVS.find(c=>c.conv_id===cid)}}catch(e){}
 if(!conv){toast('საუბარი ვერ მოიძებნა');return}await loadProfiles(conv.members||[]);S.chatGroup=conv.is_group;
 const other=!conv.is_group&&conv.members?.[0],title=conv.is_group?(conv.title||'ჯგუფი'):pname(other);
 let chan=null;
 sheet(`<div class="ph-head"><button class="ibtn" data-a="chats" aria-label="უკან">${ic('back')}</button>${conv.is_group?`<span class="av gav" style="--s:34px;--h:${(cid*47)%360}">${ic('users')}</span>`:`<button data-a="user" data-u="${other}" aria-label="პროფილი">${av(other,34)}</button>`}<div class="grow"><b>${esc(title)}${other?vb(other):''}${fire(cid)}</b><span class="sub">${conv.is_group?(conv.members.length+1)+' წევრი':isOnline(other)?'ონლაინ':'ბოლოს იყო '+ago(prof(other).last_seen||Date.now())}</span></div>
 ${other?`<button class="ibtn" data-a="call" data-u="${other}" data-v="0" aria-label="ხმოვანი ზარი">${ic('phone')}</button><button class="ibtn" data-a="call" data-u="${other}" data-v="1" aria-label="ვიდეოზარი">${ic('video')}</button>`:''}<button class="ibtn" data-a="chatmore" data-c="${cid}" aria-label="მეტი">${ic('more')}</button></div>
 <div class="ph-body chatb" id="cb">${skel(2)}</div>
 <form class="ph-foot chatfoot" id="chf"><button type="button" class="ibtn" id="ch_mic" aria-label="ხმოვანი შეტყობინება">${ic('mic')}</button><button type="button" class="ibtn" id="ch_img" aria-label="ფოტოს გაგზავნა">${ic('image')}</button><button type="button" class="ibtn stkb" id="ch_stk" aria-label="სტიკერი">🍷</button><input class="field" id="cin" maxlength="4000" placeholder="შეტყობინება…" aria-label="შეტყობინება" autocomplete="off"><button class="btn" aria-label="გაგზავნა">${ic('send')}</button></form>`,'',()=>{if(chan)sb.removeChannel(chan);S.openConv=null});
 S.openConv=cid;const cb=$('#cb'),inp=$('#cin');if(draft){inp.value=draft}
 const seen=new Set();const add=m=>{if(seen.has(m.id))return;seen.add(m.id);const c=$('#cb');if(!c)return;const near=c.scrollHeight-c.scrollTop-c.clientHeight<120;c.insertAdjacentHTML('beforeend',msgHTML(m));if(near||m.sender===ME.id)c.scrollTop=1e6};
 try{const rows=await q(sb.from('messages').select('id,sender,body,media,kind,created_at').eq('conv_id',cid).order('created_at',{ascending:false}).limit(60));await loadProfiles(rows.map(r=>r.sender));rows.reverse();cb.innerHTML=rows.length?'':'<p class="muted" id="chempty">დაწერე პირველი შეტყობინება.</p>';rows.forEach(add);cb.scrollTop=1e6}catch(e){cb.innerHTML=`<p class="muted">${errMsg(e)}</p>`}
 markRead(cid);
 chan=sb.channel('conv-'+cid).on('postgres_changes',{event:'INSERT',schema:'public',table:'messages',filter:'conv_id=eq.'+cid},async pl=>{const m=pl.new;await loadProfiles([m.sender]);$('#chempty')?.remove();add(m);if(m.sender!==ME.id)markRead(cid)}).subscribe();
 const send=async(row)=>{try{const m=await q(sb.from('messages').insert(Object.assign({conv_id:cid,sender:ME.id},row)).select('id,sender,body,media,kind,created_at').single());$('#chempty')?.remove();add(m)}catch(e){toast(errMsg(e))}};
 $('#chf').onsubmit=async e=>{e.preventDefault();const v=inp.value.trim();if(!v)return;inp.value='';const u=(v.match(/https?:\/\/[^\s<]+/)||[])[0];let link=null;if(u)link=await Promise.race([unfurl(u),new Promise(r=>setTimeout(()=>r(null),2500))]);send(link?{body:v,media:{link}}:{body:v})};
 $('#ch_stk').onclick=async()=>{const id=await pickSticker();if(!id)return;const st=STICKERS.find(x=>x[0]===id);send({body:st[1],media:{sticker:id}})};
 $('#ch_mic').onclick=async()=>{const b=await recordVoice();if(!b)return;try{const url=await uploadBlob(b,extOf(b));send({kind:'voice',media:{url,dur:b.dur||0}})}catch(e){toast(errMsg(e))}};
 $('#ch_img').onclick=async()=>{const b=await pickImage({max:1600});if(!b)return;try{toast('იტვირთება…');const url=await uploadBlob(b,'jpg');send({kind:'image',media:{url}})}catch(e){toast(errMsg(e))}}}
async function markRead(cid){try{await sb.from('conversation_members').update({last_read_at:new Date().toISOString()}).eq('conv_id',cid).eq('user_id',ME.id);const c=CONVS.find(x=>x.conv_id===cid);if(c){S.unreadMsgs=Math.max(0,S.unreadMsgs-(c.unread||0));c.unread=0;renderBadges()}}catch(e){}}
A.imgview=t=>window.open(t.dataset.src,'_blank','noopener');
A.chatmore=t=>{const cid=+t.dataset.c,conv=CONVS.find(c=>c.conv_id===cid);const other=conv&&!conv.is_group&&conv.members?.[0];
 sheet(head('საუბარი')+`<div class="reasons">${conv?.is_group?`<button data-a="gcmembers" data-c="${cid}">წევრები</button><button data-a="gcadd" data-c="${cid}">წევრის დამატება</button><button data-a="gcrename" data-c="${cid}">სახელის შეცვლა</button><button class="warnbtn" data-a="gcleave" data-c="${cid}">ჯგუფიდან გასვლა</button>`:other?`<button data-a="user" data-u="${other}">პროფილის ნახვა</button><button data-a="report" data-type="user" data-id="${other}">საჩივარი</button><button class="warnbtn" data-a="block" data-u="${other}">დაბლოკვა</button>`:''}</div>`,'short')};
function friendPicker(title,okLabel,cb,exclude=new Set()){const ids=[...FRIENDS].filter(i=>!exclude.has(i));
 sheet(head(title)+`<div class="ph-body">${cb.withTitle?'<label class="fld">ჯგუფის სახელი<input id="gct" maxlength="80" placeholder="მაგ. სუფრის ბიჭები"></label>':''}${ids.map(id=>`<label class="row pick"><input type="checkbox" value="${id}">${av(id,40)}<span class="grow"><b>${esc(pname(id))}</b></span></label>`).join('')||'<p class="muted">მეგობრები ჯერ არ გყავს.</p>'}</div><div class="ph-foot"><span class="sp"></span><button class="btn" id="pk_ok">${okLabel}</button></div>`);
 $('#pk_ok').onclick=async()=>{const sel=$$('.pick input:checked',$('#sheet')).map(i=>i.value);if(!sel.length){toast('აირჩიე მინიმუმ ერთი მეგობარი');return}try{await cb(sel,$('#gct')?.value||'')}catch(e){toast(errMsg(e))}}}
A.newgroupchat=()=>{const f=async(sel,title)=>{const c=await rpc('create_group_chat',{p_title:title,p_members:sel});CONVS=await rpc('my_conversations');openChat(c)};f.withTitle=1;friendPicker('ახალი ჯგუფური ჩატი','შექმნა',f)};
A.gcadd=t=>{const cid=+t.dataset.c,conv=CONVS.find(c=>c.conv_id===cid);friendPicker('წევრის დამატება','დამატება',async sel=>{await rpc('add_to_group_chat',{c:cid,p_members:sel});CONVS=await rpc('my_conversations');toast('დაემატა');openChat(cid)},new Set(conv?.members||[]))};
A.gcmembers=t=>{const conv=CONVS.find(c=>c.conv_id===+t.dataset.c);sheet(head('წევრები')+`<div class="ph-body">${personRow(ME)}${(conv?.members||[]).map(id=>personRow(prof(id))).join('')}</div>`)};
A.gcrename=t=>{const cid=+t.dataset.c;sheet(head('სახელის შეცვლა')+`<form class="ph-body" id="gcr"><input class="field sq" id="gcn" maxlength="80" required></form><div class="ph-foot"><span class="sp"></span><button class="btn" id="gcok">შენახვა</button></div>`,'short');$('#gcok').onclick=async()=>{try{await q(sb.from('conversations').update({title:$('#gcn').value.trim()}).eq('id',cid));CONVS=await rpc('my_conversations');openChat(cid)}catch(e){toast(errMsg(e))}}};
A.gcleave=t=>{const cid=+t.dataset.c;confirmSheet('ჯგუფიდან გასვლა','ამ ჯგუფის შეტყობინებებს აღარ მიიღებ.','გასვლა',async()=>{await q(sb.from('conversation_members').delete().eq('conv_id',cid).eq('user_id',ME.id));CONVS=CONVS.filter(c=>c.conv_id!==cid)},true)};

/* calls: WebRTC with signaling over realtime broadcast */
const CALL={pc:null,peer:null,local:null,video:false,chan:null,mine:null,ring:null,t:null,state:'idle'};
const ICE=[{urls:['stun:stun.l.google.com:19302','stun:stun1.l.google.com:19302']}];
const OUT=new Map();
function callSend(to,payload){const pl=Object.assign({from:ME.id},payload);let o=OUT.get(to);
 if(!o){const ch=sb.channel('call-'+to,{config:{broadcast:{self:false}}});o={ch,ready:false,q:[],t:null};OUT.set(to,o);ch.subscribe(st=>{if(st==='SUBSCRIBED'){o.ready=true;o.q.splice(0).forEach(x=>ch.send({type:'broadcast',event:'sig',payload:x}))}})}
 if(o.ready)o.ch.send({type:'broadcast',event:'sig',payload:pl});else o.q.push(pl);
 clearTimeout(o.t);o.t=setTimeout(()=>{sb.removeChannel(o.ch);OUT.delete(to)},60000)}
function listenCalls(){CALL.mine=sb.channel('call-'+ME.id,{config:{broadcast:{self:false}}}).on('broadcast',{event:'sig'},({payload:p})=>onSig(p)).subscribe()}
function ringTone(on){try{if(!on){CALL.ring&&CALL.ring.close();CALL.ring=null;return}const ac=new (window.AudioContext||window.webkitAudioContext)();CALL.ring=ac;const beep=()=>{if(CALL.ring!==ac)return;const o=ac.createOscillator(),g=ac.createGain();o.frequency.value=480;g.gain.value=.08;o.connect(g).connect(ac.destination);o.start();o.stop(ac.currentTime+.4);setTimeout(beep,1600)};beep()}catch(e){}}
function callUI(state,text){const el=$('#call'),u=prof(CALL.peer);el.hidden=false;
 el.innerHTML=`<div class="call-in">${CALL.video?'<video id="rv" class="rvid" autoplay playsinline></video><video id="lv" class="lvid" autoplay playsinline muted></video>':''}<div class="eyebrow" style="color:inherit;opacity:.8">${CALL.video?'ვიდეოზარი':'ხმოვანი ზარი'}</div>
 <div class="ring2${state==='live'?' still':''}">${av(u,120)}</div><div><h2>${esc(u.name)}</h2><p id="cst">${text}</p></div><audio id="ra" autoplay></audio>
 <div class="cbtns">${state==='incoming'?`<button class="end" data-a="cdecline" aria-label="უარყოფა">${ic('hangup')}</button><button class="ok" data-a="caccept" aria-label="პასუხი">${ic('phone')}</button>`:`<button data-a="cmute" aria-pressed="false" aria-label="მიკროფონის გამორთვა">${ic('micoff')}</button>${CALL.video?`<button data-a="ccam" aria-pressed="false" aria-label="კამერის გამორთვა">${ic('video')}</button>`:''}<button class="end" data-a="cend" aria-label="დასრულება">${ic('hangup')}</button>`}</div></div>`;
 if(CALL.local&&$('#lv'))$('#lv').srcObject=CALL.local;attachRemote()}
function attachRemote(){const s=CALL.remote;if(!s)return;const rv=$('#rv'),ra=$('#ra');if(rv)rv.srcObject=s;else if(ra)ra.srcObject=s}
async function getMedia(video){return navigator.mediaDevices.getUserMedia({audio:true,video:video?{facingMode:'user',width:{ideal:720}}:false})}
function newPC(){const pc=new RTCPeerConnection({iceServers:ICE});pc.onicecandidate=e=>{if(e.candidate)callSend(CALL.peer,{t:'ice',c:e.candidate})};
 pc.ontrack=e=>{CALL.remote=e.streams[0];attachRemote()};pc.onconnectionstatechange=()=>{const s=pc.connectionState;if(s==='connected'){CALL.state='live';clearTimeout(CALL.t);const st=$('#cst');if(st)st.textContent='დაკავშირებულია';$('.ring2')?.classList.add('still')}else if(s==='failed'){toast('კავშირი ვერ დამყარდა. შეიძლება ქსელი ბლოკავს ზარს');endCall(true)}else if(s==='disconnected'){setTimeout(()=>{if(CALL.pc===pc&&pc.connectionState!=='connected')endCall(true)},4000)}};return pc}
A.call=async t=>{if(CALL.state!=='idle'){toast('ზარი უკვე მიმდინარეობს');return}const to=t.dataset.u,video=t.dataset.v==='1';
 try{CALL.local=await getMedia(video)}catch(e){toast('მიკროფონზე ან კამერაზე წვდომა არ არის');return}
 Object.assign(CALL,{peer:to,video,state:'calling',remote:null});closeSheet();callUI('calling','ირეკება…');
 const pc=CALL.pc=newPC();CALL.local.getTracks().forEach(tr=>pc.addTrack(tr,CALL.local));const off=await pc.createOffer();await pc.setLocalDescription(off);
 callSend(to,{t:'offer',sdp:off.sdp,video,name:ME.name});CALL.t=setTimeout(()=>{if(CALL.state==='calling'){const st=$('#cst');if(st)st.textContent=`${pname(to)} ვერ პასუხობს`;callSend(to,{t:'end'});setTimeout(()=>endCall(true),1800)}},35000)};
async function onSig(p){if(!p||!p.from)return;if(BLOCKED.has(p.from))return;
 if(p.t==='offer'){if(CALL.state!=='idle'){callSend(p.from,{t:'busy'});return}await loadProfiles([p.from]);Object.assign(CALL,{peer:p.from,video:!!p.video,state:'incoming',offer:p.sdp,pendingIce:[],remote:null});callUI('incoming',`${p.video?'ვიდეოზარი':'ზარი'}…`);ringTone(true);CALL.t=setTimeout(()=>{if(CALL.state==='incoming')endCall(true)},40000)}
 else if(p.from!==CALL.peer)return;
 else if(p.t==='answer'&&CALL.pc){await CALL.pc.setRemoteDescription({type:'answer',sdp:p.sdp});const st=$('#cst');if(st)st.textContent='უკავშირდება…'}
 else if(p.t==='ice'){if(CALL.pc&&CALL.pc.remoteDescription)CALL.pc.addIceCandidate(p.c).catch(()=>{});else(CALL.pendingIce=CALL.pendingIce||[]).push(p.c)}
 else if(p.t==='busy'){const st=$('#cst');if(st)st.textContent='ახლა სხვა ზარზეა';setTimeout(()=>endCall(true),1800)}
 else if(p.t==='decline'){const st=$('#cst');if(st)st.textContent='ზარი უარყო';setTimeout(()=>endCall(true),1500)}
 else if(p.t==='end')endCall(true)}
A.caccept=async()=>{ringTone(false);clearTimeout(CALL.t);try{CALL.local=await getMedia(CALL.video)}catch(e){toast('მიკროფონზე წვდომა არ არის');callSend(CALL.peer,{t:'decline'});endCall(true);return}
 CALL.state='connecting';callUI('live','უკავშირდება…');const pc=CALL.pc=newPC();CALL.local.getTracks().forEach(tr=>pc.addTrack(tr,CALL.local));
 await pc.setRemoteDescription({type:'offer',sdp:CALL.offer});(CALL.pendingIce||[]).forEach(c=>pc.addIceCandidate(c).catch(()=>{}));const ans=await pc.createAnswer();await pc.setLocalDescription(ans);callSend(CALL.peer,{t:'answer',sdp:ans.sdp})};
A.cdecline=()=>{callSend(CALL.peer,{t:'decline'});endCall(true)};
A.cend=()=>{if(CALL.peer)callSend(CALL.peer,{t:'end'});endCall(true)};
A.cmute=t=>{const on=t.getAttribute('aria-pressed')!=='true';t.setAttribute('aria-pressed',String(on));CALL.local?.getAudioTracks().forEach(tr=>tr.enabled=!on)};
A.ccam=t=>{const on=t.getAttribute('aria-pressed')!=='true';t.setAttribute('aria-pressed',String(on));CALL.local?.getVideoTracks().forEach(tr=>tr.enabled=!on)};
function endCall(){ringTone(false);clearTimeout(CALL.t);try{CALL.pc&&CALL.pc.close()}catch(e){}CALL.local&&CALL.local.getTracks().forEach(t=>t.stop());Object.assign(CALL,{pc:null,peer:null,local:null,remote:null,state:'idle'});const el=$('#call');el.hidden=true;el.innerHTML=''}
