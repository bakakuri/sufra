/* messenger: conversations, realtime chat, replies, edits, pins, disappearing messages, voice, photo, location, cards, calls */
let CONVS=[],STREAK=new Map(),CHAT=null;
async function loadStreaks(){try{const r=await rpc('dm_streaks');STREAK=new Map(r.map(x=>[x.conv_id,x.streak]))}catch(e){}}
const fire=cid=>STREAK.get(cid)?`<span class="fire" title="${STREAK.get(cid)} დღე ზედიზედ">🔥${STREAK.get(cid)}</span>`:'';
const TTL_TXT={3600:'1 საათი',86400:'24 საათი',604800:'7 დღე'};
const MSEL='id,sender,body,media,kind,created_at,reply_to,edited_at,deleted,expires_at';
const lastTxt=c=>c.last_kind==='voice'?'🎤 ხმოვანი':c.last_kind==='image'?'📷 ფოტო':c.last_body||(c.last_kind==='text'?'შეტყობინება წაიშალა':'');
async function openChats(){sheet(head('მიმოწერა',`<button class="btn sm ghost" data-a="newgroupchat">${ic('users')}ჯგუფი</button>`)+`<div class="ph-body" id="chl">${skel(4)}</div>`);
 try{[CONVS]=await Promise.all([rpc('my_conversations'),loadStreaks()]);await loadProfiles(CONVS.flatMap(c=>c.members||[]));const el=$('#chl');if(!el)return;
  el.innerHTML=CONVS.map(c=>{const other=!c.is_group&&c.members?.[0],title=c.is_group?(c.title||'ჯგუფი'):pname(other);
   return `<button class="row" data-a="chat" data-c="${c.conv_id}">${c.is_group?`<span class="av gav" style="--s:48px;--h:${(c.conv_id*47)%360}">${ic('users')}</span>`:av(other,48)}<span class="grow"><b>${esc(title)}${other?vb(other):''}${fire(c.conv_id)}</b><span class="sub">${c.last_sender===ME.id?'შენ: ':''}${esc(lastTxt(c))} · ${ago(c.last_message_at)}</span></span>${c.unread?`<span class="badge">${c.unread}</span>`:other&&isOnline(other)?'<i class="ond" aria-label="ონლაინ"></i>':''}</button>`}).join('')||empty('მიმოწერა ჯერ ცარიელია','მეგობრის პროფილზე დააჭირე „მიწერა“.','<button class="btn" data-a="page" data-p="friends">მეგობრები</button>')}catch(e){const el=$('#chl');if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
A.chats=()=>openChats();
A.chat=t=>openChat(+t.dataset.c);
A.chatwith=t=>openChatWith(t.dataset.u);
async function openChatWith(uid,draft){try{const c=await rpc('start_dm',{other:uid});openChat(c,draft)}catch(e){toast(errMsg(e))}}

/* one message */
const snip=m=>!m?'შეტყობინება':m.deleted?'წაშლილი შეტყობინება':m.kind==='voice'?'🎤 ხმოვანი':m.kind==='image'?'📷 ფოტო':m.media?.sticker?'სტიკერი':m.media?.card?'🎉 მისალოცი ბარათი':m.media?.loc?'📍 ლოკაცია':m.media?.post?'📝 პოსტი':String(m.body||'').slice(0,90);
const hhmm=ts=>new Date(ts).toLocaleTimeString('ka-GE',{hour:'2-digit',minute:'2-digit'});
/* a small map made of OpenStreetMap tiles, centred on the point (no map library needed) */
function locCard(l){const lat=+l.lat,lng=+l.lng;if(!isFinite(lat)||!isFinite(lng))return '';const href=`https://www.openstreetmap.org/?mlat=${lat.toFixed(6)}&mlon=${lng.toFixed(6)}#map=16/${lat.toFixed(5)}/${lng.toFixed(5)}`;
 let tiles='';if(!ECO()){const z=15,W=240,H=140,n=256*2**z,px=(lng+180)/360*n,r=lat*Math.PI/180,py=(1-Math.log(Math.tan(r)+1/Math.cos(r))/Math.PI)/2*n,x0=px-W/2,y0=py-H/2;
  for(let tx=Math.floor(x0/256);tx<=Math.floor((x0+W)/256);tx++)for(let ty=Math.floor(y0/256);ty<=Math.floor((y0+H)/256);ty++)tiles+=`<img src="https://tile.openstreetmap.org/${z}/${tx}/${ty}.png" alt="" loading="lazy" referrerpolicy="strict-origin-when-cross-origin" style="left:${Math.round(tx*256-x0)}px;top:${Math.round(ty*256-y0)}px">`}
 return `<a class="loccard" href="${href}" target="_blank" rel="noopener">${tiles?`<span class="locmap">${tiles}<i class="locpin">${ic('pin','currentColor')}</i></span>`:''}<span class="loct">${ic('pin')}<b>ლოკაცია</b><small>${l.acc?'±'+Math.round(l.acc)+' მ · ':''}რუკაზე ნახვა</small></span></a><span class="osmc">© OpenStreetMap</span>`}
/* a shared post inside a chat */
const postMsg=(p,me)=>`<button class="mpost${me?' me':''}" data-a="chpost" data-pid="${+p.id||0}">${safeU(p.img)?`<img src="${esc(p.img)}" alt="" loading="lazy">`:`<span class="mpi">${ic('image')}</span>`}<span class="mpt"><b>${esc(p.by||'პოსტი')}</b><small>${esc(String(p.t||'').slice(0,120))||'პოსტის ნახვა'}</small></span></button>`;
A.chpost=t=>{const id=+t.dataset.pid;if(!id)return;closeSheet();openPage('post',id)};
function msgHTML(m){const me=m.sender===ME.id,u=prof(m.sender);let body;
 if(m.kind==='system')return `<div class="sysmsg" data-mid="${m.id}">${esc(m.body)}</div>`;
 if(m.deleted)body=`<div class="bubble del${me?' me':''}">${ic('block')}შეტყობინება წაიშალა</div>`;
 else if(m.kind==='voice'&&m.media?.url)body=`<div class="bubble vmsg${me?' me':''}"><audio controls preload="metadata" src="${esc(m.media.url)}"></audio><span>${m.media.dur?m.media.dur+' წმ':'ხმოვანი'}</span></div>`;
 else if(m.kind==='image'&&m.media?.url)body=`<div class="bubble img${me?' me':''}"><img src="${esc(mSm(m.media))}" alt="" loading="lazy" data-a="imgview" data-src="${esc(m.media.url)}"></div>`;
 else if(m.media?.sticker)body=`<div class="stkmsg">${stickerSVG(m.media.sticker)}</div>`;
 else if(m.media?.card)body=cardHTML(m.media.card);
 else if(m.media?.loc)body=locCard(m.media.loc);
 else if(m.media?.post)body=postMsg(m.media.post,me);
 else body=(me?`<div class="bubble me">${linkify(m.body)}</div>`:tx(m.body,'bubble'))+(m.media?.link?linkCard(m.media.link,'inchat'):'');
 const r=m.reply_to&&!m.deleted?CHAT?.msgs.get(m.reply_to):null;
 const rq=m.reply_to&&!m.deleted?`<button class="rquote" data-a="jumpmsg" data-mid="${m.reply_to}"><b>${r?esc(String(pname(r.sender)).split(' ')[0]):'პასუხი'}</b><span>${esc(snip(r))}</span></button>`:'';
 const fw=m.media?.fwd&&!m.deleted?`<span class="fwdl">${ic('fwd')}გადმოგზავნილი · ${esc(m.media.fwd)}</span>`:'';
 return `<div class="mrow${me?' me':''}" data-mid="${m.id}">${!me&&S.chatGroup?`<button class="mav" data-a="user" data-u="${m.sender}" aria-label="${esc(u.name)}">${av(u,26)}</button>`:''}<div class="mcol">${!me&&S.chatGroup?`<span class="mname">${esc(String(u.name).split(' ')[0])}</span>`:''}${fw}${rq}${body}<span class="mtime">${hhmm(m.created_at)}${m.edited_at&&!m.deleted?' · რედაქტირებული':''}${m.expires_at?` <i class="mttl" title="ქრება ${fdate(m.expires_at)}">${ic('timer')}</i>`:''}</span></div>${m.deleted?'':`<button class="mact" data-a="msgact" data-mid="${m.id}" aria-label="მოქმედებები">${ic('more')}</button>`}</div>`}
function redrawMsg(id){const m=CHAT&&CHAT.msgs.get(id),el=$(`#cb [data-mid="${id}"]`);if(!m||!el)return;el.outerHTML=msgHTML(m);$$(`#cb .rquote[data-mid="${id}"]`).forEach(q=>{const row=q.closest('[data-mid]');if(row)redrawMsg(+row.dataset.mid)})}

async function openChat(cid,draft=''){let conv=CONVS.find(c=>c.conv_id===cid);
 try{if(!conv){CONVS=await rpc('my_conversations');conv=CONVS.find(c=>c.conv_id===cid)}}catch(e){}
 if(!conv){toast('საუბარი ვერ მოიძებნა');return}await loadProfiles(conv.members||[]);S.chatGroup=conv.is_group;
 const other=!conv.is_group&&conv.members?.[0],title=conv.is_group?(conv.title||'ჯგუფი'):pname(other);
 let chan=null;const st=CHAT={cid,conv,other,msgs:new Map(),reply:null,edit:null,pinned:null,ttl:null,timers:[],seen:new Map(),typing:new Map()};
 sheet(`<div class="ph-head"><button class="ibtn" data-a="chats" aria-label="უკან">${ic('back')}</button>${conv.is_group?`<span class="av gav" style="--s:34px;--h:${(cid*47)%360}">${ic('users')}</span>`:`<button data-a="user" data-u="${other}" aria-label="პროფილი">${av(other,34)}</button>`}<div class="grow"><b>${esc(title)}${other?vb(other):''}${fire(cid)}</b><span class="sub" id="chsub">${conv.is_group?(conv.members.length+1)+' წევრი':isOnline(other)?'ონლაინ':'ბოლოს იყო '+ago(prof(other).last_seen||Date.now())}</span></div>
 ${other?`<button class="ibtn" data-a="call" data-u="${other}" data-v="0" aria-label="ხმოვანი ზარი">${ic('phone')}</button><button class="ibtn" data-a="call" data-u="${other}" data-v="1" aria-label="ვიდეოზარი">${ic('video')}</button>`:''}<button class="ibtn" data-a="chatmore" data-c="${cid}" aria-label="მეტი">${ic('more')}</button></div>
 <button class="pinbar" id="pinb" data-a="jumppin" hidden></button>
 <div class="ph-body chatb" id="cb">${skel(2)}</div>
 <form class="ph-foot chatfoot" id="chf"><div class="replybar" id="rpb" hidden></div><div class="chrow"><button type="button" class="ibtn" id="ch_more" aria-label="დამატება">${ic('plus')}</button><button type="button" class="ibtn" id="ch_mic" aria-label="ხმოვანი შეტყობინება">${ic('mic')}</button><button type="button" class="ibtn stkb" id="ch_stk" aria-label="სტიკერი">🍷</button><input class="field" id="cin" maxlength="4000" placeholder="შეტყობინება…" aria-label="შეტყობინება" autocomplete="off"><button class="btn" aria-label="გაგზავნა">${ic('send')}</button></div></form>`,'',()=>{if(chan)sb.removeChannel(chan);st.timers.forEach(clearTimeout);st.typing.forEach(clearTimeout);if(CHAT===st)CHAT=null;S.openConv=null});
 S.openConv=cid;const cb=$('#cb'),inp=$('#cin');if(draft){inp.value=draft}
 const expire=m=>{if(!m.expires_at)return;const ms=new Date(m.expires_at)-Date.now();if(ms<2147e6)st.timers.push(setTimeout(()=>{st.msgs.delete(m.id);$(`#cb [data-mid="${m.id}"]`)?.remove()},Math.max(0,ms)))};
 const add=m=>{if(st.msgs.has(m.id))return;st.msgs.set(m.id,m);const c=$('#cb');if(!c)return;const near=c.scrollHeight-c.scrollTop-c.clientHeight<120;c.insertAdjacentHTML('beforeend',msgHTML(m));expire(m);drawSeen();if(near||m.sender===ME.id)c.scrollTop=1e6};
 /* "seen" under my last message, when it is the last one; hidden both ways for people who turned read receipts off */
 const drawSeen=()=>{const c=$('#cb');if(!c||CHAT!==st)return;$$('.seenmark',c).forEach(e=>e.remove());if(ME.privacy?.read===false)return;
  const last=[...st.msgs.values()].filter(m=>!m._old&&m.kind!=='system').sort((a,b)=>new Date(a.created_at)-new Date(b.created_at)).pop();if(!last||last.sender!==ME.id||last.deleted)return;
  const t=new Date(last.created_at).getTime(),by=[...st.seen.entries()].filter(([,v])=>v&&new Date(v).getTime()>=t).map(([u])=>u),row=$(`[data-mid="${last.id}"]`,c);if(!row)return;
  const txt=by.length?(conv.is_group?`ნახა ${by.length}`:`ნანახია · ${hhmm(st.seen.get(by[0]))}`):'გაგზავნილია';
  row.insertAdjacentHTML('afterend',`<div class="seenmark${by.length?' on':''}">${ic(by.length?'eye':'check')}${txt}</div>`)};
 const drawTyping=()=>{const s=$('#chsub');if(!s||CHAT!==st)return;const who=[...st.typing.keys()];
  if(!who.length){if(st.subBase!=null){s.innerHTML=st.subBase;st.subBase=null}s.classList.remove('typing');return}
  if(st.subBase==null)st.subBase=s.innerHTML;s.classList.add('typing');s.innerHTML=(conv.is_group?esc(who.map(u=>String(pname(u)).split(' ')[0]).slice(0,2).join(', '))+' ':'')+'წერს<span class="tdots" aria-hidden="true"><i></i><i></i><i></i></span>'};
 const stopTyping=u=>{if(!st.typing.has(u))return;clearTimeout(st.typing.get(u));st.typing.delete(u);drawTyping()};
 st.add=add;
 const meta=async()=>{try{const c=await q(sb.from('conversations').select('pinned_msg,ttl').eq('id',cid).maybeSingle());if(CHAT!==st||!c)return;st.ttl=c.ttl;st.pinned=c.pinned_msg;
  if(st.pinned&&!st.msgs.has(st.pinned)){const pm=await q(sb.from('messages').select(MSEL).eq('id',st.pinned).maybeSingle());if(pm)st.pinMsg=pm}drawPin();const s=$('#chsub');if(s&&st.ttl&&!s.querySelector('.ttlc'))s.insertAdjacentHTML('afterbegin',`<span class="ttlc">${ic('timer')}${TTL_TXT[st.ttl]}</span> · `);else if(s&&!st.ttl)s.querySelector('.ttlc')?.remove()}catch(e){}};
 try{const rows=await q(sb.from('messages').select(MSEL).eq('conv_id',cid).order('created_at',{ascending:false}).limit(60));await loadProfiles(rows.map(r=>r.sender));rows.reverse();
  const miss=[...new Set(rows.map(r=>r.reply_to).filter(id=>id&&!rows.some(x=>x.id===id)))];if(miss.length){try{(await q(sb.from('messages').select(MSEL).in('id',miss))).forEach(x=>st.msgs.set(x.id,Object.assign(x,{_old:1})))}catch(e){}}
  rows.forEach(r=>st.msgs.set(r.id,r));cb.innerHTML=rows.length?rows.map(msgHTML).join(''):'<p class="muted" id="chempty">დაწერე პირველი შეტყობინება.</p>';rows.forEach(expire);cb.scrollTop=1e6}catch(e){cb.innerHTML=`<p class="muted">${errMsg(e)}</p>`}
 q(sb.from('conversation_members').select('user_id,seen_at').eq('conv_id',cid)).then(ms=>{if(CHAT!==st)return;ms.forEach(r=>{if(r.user_id!==ME.id)st.seen.set(r.user_id,r.seen_at)});drawSeen()}).catch(()=>{});
 meta();markRead(cid);
 if(matchMedia('(hover:none)').matches&&!store.get('tip:hold',0)){store.set('tip:hold',1);setTimeout(()=>{if(CHAT===st)toast('შეტყობინებას დიდხანს დააჭირე: პასუხი, გადაგზავნა, მიმაგრება')},1200)}
 chan=sb.channel('conv-'+cid).on('postgres_changes',{event:'INSERT',schema:'public',table:'messages',filter:'conv_id=eq.'+cid},async pl=>{const m=pl.new;await loadProfiles([m.sender]);$('#chempty')?.remove();stopTyping(m.sender);add(m);if(m.kind==='system')meta();if(m.sender!==ME.id)markRead(cid)})
  .on('postgres_changes',{event:'UPDATE',schema:'public',table:'conversation_members',filter:'conv_id=eq.'+cid},pl=>{const r=pl.new;if(!r||r.user_id===ME.id)return;st.seen.set(r.user_id,r.seen_at);drawSeen()})
  .on('broadcast',{event:'typing'},({payload})=>{const u=payload&&payload.u;if(!u||u===ME.id||!(conv.members||[]).includes(u))return;clearTimeout(st.typing.get(u));st.typing.set(u,setTimeout(()=>stopTyping(u),4500));drawTyping()})
  .on('postgres_changes',{event:'UPDATE',schema:'public',table:'messages',filter:'conv_id=eq.'+cid},pl=>{const m=pl.new;if(!st.msgs.has(m.id))return;st.msgs.set(m.id,Object.assign(st.msgs.get(m.id),m));redrawMsg(m.id);if(m.deleted&&st.pinned===m.id){st.pinned=null;drawPin()}}).subscribe();
 const send=async(row)=>{if(st.reply){row.reply_to=st.reply.id;setReply(null)}try{const m=await q(sb.from('messages').insert(Object.assign({conv_id:cid,sender:ME.id},row)).select(MSEL).single());$('#chempty')?.remove();add(m)}catch(e){toast(errMsg(e))}};
 st.send=send;
 let typT=0;inp.addEventListener('input',()=>{if(ME.privacy?.read===false||!chan||!inp.value.trim())return;const n=Date.now();if(n-typT<2500)return;typT=n;try{chan.send({type:'broadcast',event:'typing',payload:{u:ME.id}})}catch(e){}});
 $('#chf').onsubmit=async e=>{e.preventDefault();const v=inp.value.trim();if(!v)return;inp.value='';
  if(st.edit){const m=st.edit;setEdit(null);try{await rpc('edit_message',{p_id:m.id,p_body:v});Object.assign(m,{body:v,edited_at:new Date().toISOString()});redrawMsg(m.id)}catch(x){toast(errMsg(x));inp.value=v}return}
  const u=(v.match(/https?:\/\/[^\s<]+/)||[])[0];let link=null;if(u)link=await Promise.race([unfurl(u),new Promise(r=>setTimeout(()=>r(null),2500))]);send(link?{body:v,media:{link}}:{body:v})};
 $('#ch_stk').onclick=async()=>{const id=await pickSticker();if(!id)return;const s=STICKERS.find(x=>x[0]===id);send({body:s[1],media:{sticker:id}})};
 $('#ch_mic').onclick=async()=>{const b=await recordVoice();if(!b)return;try{const url=await uploadBlob(b,extOf(b));send({kind:'voice',media:{url,dur:b.dur||0}})}catch(e){toast(errMsg(e))}};
 $('#ch_more').onclick=()=>layer(lhead('დამატება')+`<div class="reasons"><button data-a="chimg">${ic('image')} ფოტო</button><button data-a="chloc">${ic('pin')} ჩემი ლოკაცია</button><button data-a="chcard">${ic('card')} მისალოცი ბარათი</button></div>`)}
A.chimg=async()=>{closeLayer();const st=CHAT;if(!st)return;const b=await pickImage({max:ECO()?1080:1600});if(!b)return;try{toast('იტვირთება…');const m=await uploadMedia(b,'image');st.send({kind:'image',media:{url:m.url,sm:m.sm||undefined,w:m.w,h:m.h}})}catch(e){toast(errMsg(e))}};
A.chloc=()=>{closeLayer();const st=CHAT;if(!st)return;if(!navigator.geolocation){toast('ამ მოწყობილობაზე ლოკაცია მიუწვდომელია');return}toast('ლოკაციას ვადგენ…');
 navigator.geolocation.getCurrentPosition(p=>{const{latitude:lat,longitude:lng,accuracy:acc}=p.coords;st.send({body:'📍 ლოკაცია',media:{loc:{lat:+lat.toFixed(6),lng:+lng.toFixed(6),acc:Math.round(acc)}}})},()=>toast('ლოკაციაზე წვდომა არ მოგვეცა. ჩართე ბრაუზერის პარამეტრებში'),{enableHighAccuracy:true,timeout:15000,maximumAge:30000})};
A.chcard=()=>{closeLayer();if(CHAT)openCardPicker({cid:CHAT.cid,uid:CHAT.other||null,kind:'g'})};
function drawPin(){const b=$('#pinb'),st=CHAT;if(!b||!st)return;const m=st.pinned&&(st.msgs.get(st.pinned)||st.pinMsg);b.hidden=!m;if(m)b.innerHTML=`${ic('pin')}<span class="grow"><b>მიმაგრებული</b><span>${esc(snip(m))}</span></span><span class="ibtn sm" data-a="unpin" role="button" aria-label="მოხსნა">${ic('x')}</span>`}
A.jumppin=t=>{if(CHAT?.pinned)jumpTo(CHAT.pinned)};
A.jumpmsg=t=>jumpTo(+t.dataset.mid);
function jumpTo(id){const el=$(`#cb [data-mid="${id}"]`);if(!el){toast('ეს შეტყობინება ძველია და აქ აღარ ჩანს');return}el.scrollIntoView({block:'center',behavior:RM()?'auto':'smooth'});el.classList.remove('flash');void el.offsetWidth;el.classList.add('flash')}
A.unpin=async(t,e)=>{e?.stopPropagation();const st=CHAT;if(!st)return;try{await rpc('pin_message',{p_conv:st.cid,p_msg:null});st.pinned=null;drawPin()}catch(x){toast(errMsg(x))}};
function setReply(m){const st=CHAT;if(!st)return;st.reply=m;if(m)st.edit=null;const b=$('#rpb');if(!b)return;b.hidden=!m;b.innerHTML=m?`${ic('reply')}<span class="grow"><b>${esc(String(pname(m.sender)).split(' ')[0])}</b><span>${esc(snip(m))}</span></span><button type="button" class="ibtn sm" id="rpx" aria-label="გაუქმება">${ic('x')}</button>`:'';const x=$('#rpx');if(x)x.onclick=()=>{setReply(null);setEdit(null)};if(m)$('#cin')?.focus()}
function setEdit(m){const st=CHAT;if(!st)return;st.edit=m;const b=$('#rpb'),inp=$('#cin');if(m){st.reply=null;b.hidden=false;b.innerHTML=`${ic('edit')}<span class="grow"><b>რედაქტირება</b><span>${esc(snip(m))}</span></span><button type="button" class="ibtn sm" id="rpx" aria-label="გაუქმება">${ic('x')}</button>`;$('#rpx').onclick=()=>{setEdit(null);inp.value=''};inp.value=m.body;inp.focus()}else if(!st.reply){b.hidden=true;b.innerHTML=''}}
A.msgact=t=>{const st=CHAT,m=st&&st.msgs.get(+t.dataset.mid);if(!m)return;const me=m.sender===ME.id,plain=m.kind==='text'&&!m.media?.sticker&&!m.media?.card&&!m.media?.loc&&!m.media?.fwd;
 const canEdit=me&&plain&&Date.now()-new Date(m.created_at)<48*36e5;
 layer(lhead('შეტყობინება')+`<div class="reasons"><button data-a="mreply" data-mid="${m.id}">${ic('reply')} პასუხი</button>${m.body&&plain?`<button data-a="mcopy" data-mid="${m.id}">${ic('note')} კოპირება</button>`:''}<button data-a="mfwd" data-mid="${m.id}">${ic('fwd')} გადაგზავნა</button><button data-a="mpin" data-mid="${m.id}">${ic('pin')} ${st.pinned===m.id?'მიმაგრების მოხსნა':'მიმაგრება'}</button>${canEdit?`<button data-a="medit" data-mid="${m.id}">${ic('edit')} რედაქტირება</button>`:''}${me?`<button class="warnbtn" data-a="munsend" data-mid="${m.id}">${ic('trash')} ყველასთვის წაშლა</button>`:`<button data-a="mreport" data-mid="${m.id}">${ic('flag')} საჩივარი</button>`}</div>`)};
const cm=t=>CHAT&&CHAT.msgs.get(+t.dataset.mid);
A.mreply=t=>{closeLayer();setReply(cm(t))};
A.medit=t=>{closeLayer();setEdit(cm(t))};
A.mcopy=async t=>{closeLayer();try{await navigator.clipboard.writeText(cm(t).body);toast('დაკოპირდა')}catch(e){toast('ვერ დაკოპირდა')}};
A.mpin=async t=>{const m=cm(t),st=CHAT;closeLayer();if(!m||!st)return;const on=st.pinned!==m.id;try{await rpc('pin_message',{p_conv:st.cid,p_msg:on?m.id:null});st.pinned=on?m.id:null;drawPin()}catch(e){toast(errMsg(e))}};
A.munsend=async t=>{const m=cm(t);closeLayer();if(!m)return;try{await rpc('unsend_message',{p_id:m.id});Object.assign(m,{deleted:true,body:'',media:null});redrawMsg(m.id);if(CHAT.pinned===m.id){CHAT.pinned=null;drawPin()}}catch(e){toast(errMsg(e))}};
A.mreport=t=>{const m=cm(t);closeLayer();if(m)A.report({dataset:{type:'message',id:String(m.id)}})};
A.mfwd=async t=>{const m=cm(t);if(!m)return;let list=CONVS;try{if(!list.length)list=CONVS=await rpc('my_conversations');await loadProfiles(list.flatMap(c=>c.members||[]))}catch(e){}
 layer(lhead('ვის გადავუგზავნო?')+`<div class="ph-body">${list.map(c=>{const o=!c.is_group&&c.members?.[0];return `<button class="row" data-a="mfwdto" data-mid="${m.id}" data-c="${c.conv_id}">${c.is_group?`<span class="av gav" style="--s:40px;--h:${(c.conv_id*47)%360}">${ic('users')}</span>`:av(o,40)}<span class="grow"><b>${esc(c.is_group?(c.title||'ჯგუფი'):pname(o))}</b></span>${ic('send')}</button>`}).join('')||'<p class="muted">სხვა მიმოწერა ჯერ არ გაქვს.</p>'}</div>`)};
A.mfwdto=async t=>{const m=cm(t),to=+t.dataset.c;if(!m)return;t.disabled=true;const media=Object.assign({},m.media||{},{fwd:String(pname(m.sender))});
 try{await q(sb.from('messages').insert({conv_id:to,sender:ME.id,body:m.body||'',kind:m.kind==='system'?'text':m.kind,media}));closeLayer();toast('გადაიგზავნა')}catch(e){toast(errMsg(e));t.disabled=false}};
async function markRead(cid){try{await sb.from('conversation_members').update({last_read_at:new Date().toISOString()}).eq('conv_id',cid).eq('user_id',ME.id);const c=CONVS.find(x=>x.conv_id===cid);if(c){S.unreadMsgs=Math.max(0,S.unreadMsgs-(c.unread||0));c.unread=0;renderBadges()}}catch(e){}}
A.imgview=t=>{const u=String(t.dataset.src||'');if(/^https:\/\//i.test(u))window.open(u,'_blank','noopener')};
A.chatmore=t=>{const cid=+t.dataset.c,conv=CONVS.find(c=>c.conv_id===cid);const other=conv&&!conv.is_group&&conv.members?.[0];
 sheet(head('საუბარი')+`<div class="reasons"><button data-a="chttl" data-c="${cid}">${ic('timer')} თვითგაქრობადი შეტყობინებები</button>${conv?.is_group?`<button data-a="gcmembers" data-c="${cid}">წევრები</button><button data-a="gcadd" data-c="${cid}">წევრის დამატება</button><button data-a="gcrename" data-c="${cid}">სახელის შეცვლა</button><button class="warnbtn" data-a="gcleave" data-c="${cid}">ჯგუფიდან გასვლა</button>`:other?`<button data-a="user" data-u="${other}">პროფილის ნახვა</button><button data-a="report" data-type="user" data-id="${other}">საჩივარი</button><button class="warnbtn" data-a="block" data-u="${other}">დაბლოკვა</button>`:''}</div>`,'short')};
A.chttl=async t=>{const cid=+t.dataset.c;let cur=null;try{cur=(await q(sb.from('conversations').select('ttl').eq('id',cid).maybeSingle()))?.ttl||null}catch(e){}
 sheet(head('თვითგაქრობა')+`<p class="hint" style="padding:12px 16px 0">ჩართვის შემდეგ ახალი შეტყობინებები ორივე მხარეს თავისით გაქრება. ეკრანის სურათს ეს ვერ შეაჩერებს.</p><div class="reasons">${[[null,'გამორთული'],[3600,'1 საათში'],[86400,'24 საათში'],[604800,'7 დღეში']].map(([v,l])=>`<button data-a="setttl" data-c="${cid}" data-v="${v||''}"${v===cur?' aria-pressed="true"':''}>${v===cur?ic('check')+' ':''}${l}</button>`).join('')}</div>`,'short')};
A.setttl=async t=>{const cid=+t.dataset.c,v=t.dataset.v?+t.dataset.v:null;try{await rpc('set_chat_ttl',{p_conv:cid,p_ttl:v});toast(v?'თვითგაქრობა ჩაირთო':'თვითგაქრობა გამოირთო');openChat(cid)}catch(e){toast(errMsg(e))}};
function friendPicker(title,okLabel,cb,exclude=new Set()){const ids=[...FRIENDS].filter(i=>!exclude.has(i));
 sheet(head(title)+`<div class="ph-body">${cb.withTitle?'<label class="fld">ჯგუფის სახელი<input id="gct" maxlength="80" placeholder="მაგ. სუფრის ბიჭები"></label>':''}${ids.map(id=>`<label class="row pick"><input type="checkbox" value="${id}">${av(id,40)}<span class="grow"><b>${esc(pname(id))}</b></span></label>`).join('')||'<p class="muted">მეგობრები ჯერ არ გყავს.</p>'}</div><div class="ph-foot"><span class="sp"></span><button class="btn" id="pk_ok">${okLabel}</button></div>`);
 $('#pk_ok').onclick=async()=>{const sel=$$('.pick input:checked',$('#sheet')).map(i=>i.value);if(!sel.length){toast('აირჩიე მინიმუმ ერთი მეგობარი');return}try{await cb(sel,$('#gct')?.value||'')}catch(e){toast(errMsg(e))}}}
A.newgroupchat=()=>{const f=async(sel,title)=>{const c=await rpc('create_group_chat',{p_title:title,p_members:sel});CONVS=await rpc('my_conversations');openChat(c)};f.withTitle=1;friendPicker('ახალი ჯგუფური ჩატი','შექმნა',f)};
A.gcadd=t=>{const cid=+t.dataset.c,conv=CONVS.find(c=>c.conv_id===cid);friendPicker('წევრის დამატება','დამატება',async sel=>{await rpc('add_to_group_chat',{c:cid,p_members:sel});CONVS=await rpc('my_conversations');toast('დაემატა');openChat(cid)},new Set(conv?.members||[]))};
A.gcmembers=t=>{const conv=CONVS.find(c=>c.conv_id===+t.dataset.c);sheet(head('წევრები')+`<div class="ph-body">${personRow(ME)}${(conv?.members||[]).map(id=>personRow(prof(id))).join('')}</div>`)};
A.gcrename=t=>{const cid=+t.dataset.c;sheet(head('სახელის შეცვლა')+`<form class="ph-body" id="gcr"><input class="field sq" id="gcn" maxlength="80" required></form><div class="ph-foot"><span class="sp"></span><button class="btn" id="gcok">შენახვა</button></div>`,'short');$('#gcok').onclick=async()=>{try{await q(sb.from('conversations').update({title:$('#gcn').value.trim()}).eq('id',cid));CONVS=await rpc('my_conversations');openChat(cid)}catch(e){toast(errMsg(e))}}};
A.gcleave=t=>{const cid=+t.dataset.c;confirmSheet('ჯგუფიდან გასვლა','ამ ჯგუფის შეტყობინებებს აღარ მიიღებ.','გასვლა',async()=>{await q(sb.from('conversation_members').delete().eq('conv_id',cid).eq('user_id',ME.id));CONVS=CONVS.filter(c=>c.conv_id!==cid)},true)};
/* hold a message for its menu: right click on a computer, a long press on a phone (iOS has no contextmenu event) */
let LP=null;
document.addEventListener('contextmenu',e=>{const row=e.target.closest('#cb .mrow');if(!row||e.target.closest('a,audio,video'))return;e.preventDefault();if(LP&&LP.fired&&Date.now()-LP.fired<1200)return;A.msgact({dataset:{mid:row.dataset.mid}})});
document.addEventListener('pointerdown',e=>{if(e.pointerType==='mouse')return;const row=e.target.closest('#cb .mrow');if(!row||e.target.closest('a,audio,video,button.mact')||!row.dataset.mid)return;
 clearTimeout(LP?.t);LP={x:e.clientX,y:e.clientY,row,t:setTimeout(()=>{if(!LP||LP.row!==row)return;LP.fired=Date.now();try{navigator.vibrate&&navigator.vibrate(12)}catch(x){}row.classList.add('held');setTimeout(()=>row.classList.remove('held'),260);A.msgact({dataset:{mid:row.dataset.mid}})},480)}},{passive:true});
const lpCancel=e=>{if(!LP)return;if(LP.fired){if(e.type!=='pointermove')LP.upAt=Date.now();return}if(e.type==='pointermove'&&Math.hypot(e.clientX-LP.x,e.clientY-LP.y)<10)return;clearTimeout(LP.t);LP=null};
['pointerup','pointercancel','pointermove'].forEach(t=>document.addEventListener(t,lpCancel,{passive:true}));
/* the finger that opened the menu must not also press whatever opens under it */
document.addEventListener('click',e=>{if(LP&&LP.fired&&(!LP.upAt||Date.now()-LP.upAt<450)){e.stopPropagation();e.preventDefault();LP=null}},true);

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
