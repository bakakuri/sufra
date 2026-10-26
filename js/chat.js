/* messenger: conversations, realtime chat, replies, edits, pins, disappearing messages, voice, photo, location, cards, calls */
let CONVS=[],STREAK=new Map(),CHAT=null;
async function loadStreaks(){try{const r=await rpc('dm_streaks');STREAK=new Map(r.map(x=>[x.conv_id,x.streak]))}catch(e){}}
const fire=cid=>STREAK.get(cid)?`<span class="fire" title="${STREAK.get(cid)} დღე ზედიზედ">🔥${STREAK.get(cid)}</span>`:'';
const TTL_TXT={3600:'1 საათი',86400:'24 საათი',604800:'7 დღე'};
const MSEL='id,sender,body,media,kind,created_at,reply_to,edited_at,deleted,expires_at';
/* the chat list with my own mute and archive flags (older servers only have my_conversations) */
async function myChats(){try{return await rpc('my_chats')}catch(e){return await rpc('my_conversations')}}
const mutedNow=c=>!!(c&&c.muted_until&&new Date(c.muted_until)>Date.now());
const lastTxt=c=>c.last_kind==='voice'?'🎤 ხმოვანი':c.last_kind==='image'?'📷 ფოტო':c.last_body||(c.last_kind==='text'?'შეტყობინება წაიშალა':'');
let CHAT_ARCH=false;
async function openChats(arch=false){CHAT_ARCH=!!arch;navMark(arch?'chatarch':'chats',()=>openChats(arch));sheet(head(arch?'არქივი':'მიმოწერა',arch?`<button class="btn sm ghost" data-a="chats">${ic('back')}ყველა</button>`:`<button class="btn sm ghost" data-a="newgroupchat">${ic('users')}ჯგუფი</button>`)+`<div class="ph-body" id="chl">${skel(4)}</div>`);
 try{[CONVS]=await Promise.all([myChats(),loadStreaks()]);await loadProfiles(CONVS.flatMap(c=>c.members||[]));drawChatList()}catch(e){const el=$('#chl');if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
function chatRow(c){const other=!c.is_group&&c.members?.[0],title=c.is_group?(c.title||'ჯგუფი'):pname(other),mu=mutedNow(c);
 return `<button class="row" data-a="chat" data-c="${c.conv_id}">${c.is_group?`<span class="av gav" style="--s:48px;--h:${(c.conv_id*47)%360}">${ic('users')}</span>`:av(other,48)}<span class="grow"><b>${esc(title)}${other?vb(other):''}${fire(c.conv_id)}${mu?`<i class="chmu" aria-label="დადუმებულია">${ic('mute')}</i>`:''}</b><span class="sub">${c.last_sender===ME.id?'შენ: ':''}${esc(lastTxt(c))} · ${ago(c.last_message_at)}</span></span>${c.unread?`<span class="badge${mu?' muted':''}">${c.unread}</span>`:other&&isOnline(other)?'<i class="ond" aria-label="ონლაინ"></i>':''}</button>`}
function drawChatList(){const el=$('#chl');if(!el)return;const arch=CHAT_ARCH,list=CONVS.filter(c=>!!c.archived===arch),na=CONVS.filter(c=>c.archived).length,ua=CONVS.filter(c=>c.archived).reduce((s,c)=>s+(c.unread||0),0);
 el.innerHTML=(!arch&&na?`<button class="row archrow" data-a="chatarch"><span class="av gav" style="--s:48px;--h:250">${ic('archive')}</span><span class="grow"><b>არქივი</b><span class="sub">${na} საუბარი</span></span>${ua?`<span class="badge muted">${ua}</span>`:''}</button>`:'')
  +(list.map(chatRow).join('')||(arch?empty('არქივი ცარიელია','საუბარს დიდხანს დააჭირე და „არქივში“ აირჩიე.'):empty('მიმოწერა ჯერ ცარიელია','მეგობრის პროფილზე დააჭირე „მიწერა“.','<button class="btn" data-a="page" data-p="friends">მეგობრები</button>')))
  +(!arch&&list.length?'<p class="note" style="padding:8px 16px">საუბარს დიდხანს დააჭირე: დადუმება ან არქივი.</p>':'')}
A.chatarch=()=>openChats(true);
const chatUnread=()=>CONVS.filter(c=>!mutedNow(c)).reduce((a,x)=>a+(x.unread||0),0);
/* mute and archive one chat */
A.chatmenu=t=>{const cid=+t.dataset.c,c=CONVS.find(x=>x.conv_id===cid);if(!c)return;const other=!c.is_group&&c.members?.[0];
 layer(lhead(esc(c.is_group?(c.title||'ჯგუფი'):pname(other)))+`<div class="reasons"><button data-a="chmute" data-c="${cid}">${ic('mute')} ${mutedNow(c)?'ხმის ჩართვა':'დადუმება'}</button><button data-a="charch" data-c="${cid}">${ic('archive')} ${c.archived?'არქივიდან ამოღება':'არქივში გადატანა'}</button></div>`)};
A.chmute=t=>{const cid=+t.dataset.c,c=CONVS.find(x=>x.conv_id===cid);if(mutedNow(c)){setMute(cid,null);return}
 layer(lhead('დადუმება')+`<div class="reasons">${[[1,'1 საათით'],[8,'8 საათით'],[168,'1 კვირით'],[0,'სანამ თავად ჩავრთავ']].map(([h,l])=>`<button data-a="chmuteset" data-c="${cid}" data-h="${h}">${ic('mute')} ${l}</button>`).join('')}</div><p class="note" style="padding:0 16px 16px">დადუმებული საუბრიდან შეტყობინება და push აღარ მოვა. მესიჯები ჩატში ჩვეულებრივად დაგხვდება.</p>`)};
A.chmuteset=t=>{const h=+t.dataset.h;setMute(+t.dataset.c,h?new Date(Date.now()+h*36e5).toISOString():'2999-01-01T00:00:00Z')};
async function setMute(cid,until){closeLayer();try{await q(sb.from('conversation_members').update({muted_until:until}).eq('conv_id',cid).eq('user_id',ME.id));const c=CONVS.find(x=>x.conv_id===cid);if(c)c.muted_until=until;toast(until?'საუბარი დადუმდა':'ხმა ჩაირთო');drawChatList();S.unreadMsgs=chatUnread();renderBadges();if(CHAT&&CHAT.cid===cid)drawChatSub()}catch(e){toast(errMsg(e))}}
A.charch=async t=>{const cid=+t.dataset.c,c=CONVS.find(x=>x.conv_id===cid);if(!c)return;closeLayer();const v=!c.archived;
 try{await q(sb.from('conversation_members').update({archived:v}).eq('conv_id',cid).eq('user_id',ME.id));c.archived=v;toast(v?'გადავიდა არქივში. ახალი მესიჯი თავად ამოიღებს, თუ საუბარი დადუმებული არ არის':'ამოვიდა არქივიდან');if(CHAT&&CHAT.cid===cid&&v)openChats();else drawChatList()}catch(e){toast(errMsg(e))}};
A.chats=()=>{if(!navBackTo('chats'))openChats()};
A.chat=t=>openChat(+t.dataset.c);
A.chatwith=t=>openChatWith(t.dataset.u);
async function openChatWith(uid,draft){try{const c=await rpc('start_dm',{other:uid});openChat(c,draft)}catch(e){toast(errMsg(e))}}

/* one message */
const snip=m=>!m?'შეტყობინება':m.deleted?'წაშლილი შეტყობინება':m.kind==='voice'?'🎤 ხმოვანი':m.kind==='image'?'📷 ფოტო':m.media?.sticker?'სტიკერი':m.media?.card?'🎉 მისალოცი ბარათი':m.media?.loc?'📍 ლოკაცია':m.media?.post?'📝 პოსტი':m.media?.call?'📹 ჯგუფური ვიდეოზარი':m.media?.story?(m.media.act==='react'?m.body+' ისტორიაზე':'ისტორიაზე: '+String(m.body||'').slice(0,80)):String(m.body||'').slice(0,90);
const hhmm=ts=>new Date(ts).toLocaleTimeString('ka-GE',{hour:'2-digit',minute:'2-digit'});
/* a small map made of OpenStreetMap tiles, centred on the point (no map library needed) */
function locCard(l){const lat=+l.lat,lng=+l.lng;if(!isFinite(lat)||!isFinite(lng))return '';const href=`https://www.openstreetmap.org/?mlat=${lat.toFixed(6)}&mlon=${lng.toFixed(6)}#map=16/${lat.toFixed(5)}/${lng.toFixed(5)}`;
 let tiles='';if(!ECO()){const z=15,W=240,H=140,n=256*2**z,px=(lng+180)/360*n,r=lat*Math.PI/180,py=(1-Math.log(Math.tan(r)+1/Math.cos(r))/Math.PI)/2*n,x0=px-W/2,y0=py-H/2;
  for(let tx=Math.floor(x0/256);tx<=Math.floor((x0+W)/256);tx++)for(let ty=Math.floor(y0/256);ty<=Math.floor((y0+H)/256);ty++)tiles+=`<img src="https://tile.openstreetmap.org/${z}/${tx}/${ty}.png" alt="" loading="lazy" referrerpolicy="strict-origin-when-cross-origin" style="left:${Math.round(tx*256-x0)}px;top:${Math.round(ty*256-y0)}px">`}
 return `<a class="loccard" href="${href}" target="_blank" rel="noopener">${tiles?`<span class="locmap">${tiles}<i class="locpin">${ic('pin','currentColor')}</i></span>`:''}<span class="loct">${ic('pin')}<b>ლოკაცია</b><small>${l.acc?'±'+Math.round(l.acc)+' მ · ':''}რუკაზე ნახვა</small></span></a><span class="osmc">© OpenStreetMap</span>`}
/* a shared post inside a chat */
const postMsg=(p,me)=>`<button class="mpost${me?' me':''}" data-a="chpost" data-pid="${+p.id||0}">${safeU(p.img)?`<img src="${esc(p.img)}" alt="" loading="lazy">`:`<span class="mpi">${ic('image')}</span>`}<span class="mpt"><b>${esc(p.by||'პოსტი')}</b><small>${esc(String(p.t||'').slice(0,120))||'პოსტის ნახვა'}</small></span></button>`;
A.chpost=t=>{const id=+t.dataset.pid;if(!id)return;closeSheet();openPage('post',id)};
/* reactions under a message: the three most used, the total, and mine highlighted */
const MREACT=['❤️','😂','😮','😢','👍','🍷','🔥','🙏'];
function reactPill(id){const r=CHAT?.reacts?.get(id);if(!r||!r.size)return '';const cnt={};r.forEach(e=>{cnt[e]=(cnt[e]||0)+1});const top=Object.entries(cnt).sort((a,b)=>b[1]-a[1]).slice(0,3).map(x=>rg(x[0])).join('');
 return `<button class="mreact${r.has(ME.id)?' mine':''}" data-a="mreacts" data-mid="${id}" aria-label="რეაქციები: ${r.size}">${top}${r.size>1?`<b>${r.size}</b>`:''}</button>`}
/* an answer or an emoji on a story: the story's picture with what happened */
function storyMsg(m,me){const d=m.media,react=d.act==='react',vid=d.type==='video';
 const lbl=react?(me?'რეაქცია ისტორიაზე':'რეაქცია შენს ისტორიაზე'):(me?'პასუხი ისტორიაზე':'პასუხი შენს ისტორიაზე');
 return `<div class="stmsg${me?' me':''}"><span class="stlbl">${ic('story')}${lbl}</span><button class="stthumb" data-a="stview" data-src="${esc(d.url)}" data-v="${vid?1:0}" aria-label="ისტორიის ნახვა">${vid?`<video src="${esc(d.url)}#t=0.5" muted playsinline preload="metadata"></video><i class="svplay">${ic('play')}</i>`:`<img src="${esc(d.url)}" alt="" loading="lazy">`}<span class="stgone">ისტორია აღარ არის</span></button>${react?`<span class="stemo">${m.body==='🍷'?rg(m.body):esc(String(m.body||'').slice(0,16))}</span>`:me?`<div class="bubble me">${linkify(m.body)}</div>`:tx(m.body,'bubble')}</div>`}
A.stview=t=>{if(t.closest('.stmsg.gone'))return;openImage(t.dataset.src,{top:true,video:t.dataset.v==='1'})};
document.addEventListener('error',e=>{const el=e.target;if(el&&el.closest&&el.closest('.stthumb'))el.closest('.stmsg')?.classList.add('gone')},true);
function msgHTML(m){const me=m.sender===ME.id,u=prof(m.sender);let body;
 if(m.kind==='system')return `<div class="sysmsg" data-mid="${m.id}">${esc(m.body)}</div>`;
 if(m.deleted)body=`<div class="bubble del${me?' me':''}">${ic('block')}შეტყობინება წაიშალა</div>`;
 else if(m.kind==='voice'&&m.media?.url)body=`<div class="bubble vmsg${me?' me':''}"><audio controls preload="metadata" src="${esc(m.media.url)}"></audio><span>${m.media.dur?m.media.dur+' წმ':'ხმოვანი'}</span></div>`;
 else if(m.kind==='image'&&m.media?.url)body=`<div class="bubble img${me?' me':''}"><img src="${esc(mSm(m.media))}" alt="" loading="lazy" data-a="imgview" data-src="${esc(m.media.url)}"></div>`;
 else if(m.media?.story&&safeU(m.media.url))body=storyMsg(m,me);
 else if(m.media?.sticker)body=`<div class="stkmsg">${stickerSVG(m.media.sticker)}</div>`;
 else if(m.media?.card)body=cardHTML(m.media.card);
 else if(m.media?.loc)body=locCard(m.media.loc);
 else if(m.media?.post)body=postMsg(m.media.post,me);
 else if(m.media?.game&&typeof gameMsg==='function'&&gameMsg(m.media.game,me,m))body=gameMsg(m.media.game,me,m);
 else if(m.media?.call&&/^\d{1,18}$/.test(String(m.media.call)))body=`<button class="callmsg${me?' me':''}" data-a="joincall" data-r="${m.media.call}"><span class="cmi">${ic('video')}</span><span class="grow"><b>ჯგუფური ვიდეოზარი</b><small>${esc(String(pname(m.sender)).split(' ')[0])} იწყებს · შემოერთება</small></span></button>`;
 else body=(me?`<div class="bubble me">${linkify(m.body)}</div>`:tx(m.body,'bubble'))+(m.media?.link?linkCard(m.media.link,'inchat'):'');
 const r=m.reply_to&&!m.deleted?CHAT?.msgs.get(m.reply_to):null;
 const rq=m.reply_to&&!m.deleted?`<button class="rquote" data-a="jumpmsg" data-mid="${m.reply_to}"><b>${r?esc(String(pname(r.sender)).split(' ')[0]):'პასუხი'}</b><span>${esc(snip(r))}</span></button>`:'';
 const fw=m.media?.fwd&&!m.deleted?`<span class="fwdl">${ic('fwd')}გადმოგზავნილი · ${esc(m.media.fwd)}</span>`:'';
 const rx=m.deleted?'':reactPill(m.id);
 return `<div class="mrow${me?' me':''}" data-mid="${m.id}">${!me&&S.chatGroup?`<button class="mav" data-a="user" data-u="${m.sender}" aria-label="${esc(u.name)}">${av(u,26)}</button>`:''}<div class="mcol">${!me&&S.chatGroup?`<span class="mname">${esc(String(u.name).split(' ')[0])}</span>`:''}${fw}${rq}${body}${rx}<span class="mtime">${hhmm(m.created_at)}${m.edited_at&&!m.deleted?' · რედაქტირებული':''}${m.expires_at?` <i class="mttl" title="ქრება ${fdate(m.expires_at)}">${ic('timer')}</i>`:''}</span></div>${m.deleted?'':`<button class="mact" data-a="msgact" data-mid="${m.id}" aria-label="მოქმედებები">${ic('more')}</button>`}</div>`}
function redrawMsg(id){const m=CHAT&&CHAT.msgs.get(id),el=$(`#cb [data-mid="${id}"]`);if(!m||!el)return;el.outerHTML=msgHTML(m);$$(`#cb .rquote[data-mid="${id}"]`).forEach(q=>{const row=q.closest('[data-mid]');if(row)redrawMsg(+row.dataset.mid)})}

async function openChat(cid,draft=''){let conv=CONVS.find(c=>c.conv_id===cid);
 try{if(!conv){CONVS=await myChats();conv=CONVS.find(c=>c.conv_id===cid)}}catch(e){}
 if(!conv){toast('საუბარი ვერ მოიძებნა');return}await loadProfiles(conv.members||[]);S.chatGroup=conv.is_group;
 const other=!conv.is_group&&conv.members?.[0],title=conv.is_group?(conv.title||'ჯგუფი'):pname(other);
 let chan=null;const st=CHAT={cid,conv,other,msgs:new Map(),reply:null,edit:null,pinned:null,ttl:null,timers:[],seen:new Map(),typing:new Map(),reacts:new Map(),more:false,oldBusy:false};
 navMark('chat',()=>openChat(cid));sheet(`<div class="ph-head"><button class="ibtn" data-a="chats" aria-label="უკან">${ic('back')}</button>${conv.is_group?`<span class="av gav" style="--s:34px;--h:${(cid*47)%360}">${ic('users')}</span>`:`<button data-a="user" data-u="${other}" aria-label="პროფილი">${av(other,34)}</button>`}<div class="grow"><b>${esc(title)}${other?vb(other):''}${fire(cid)}</b><span class="sub" id="chsub">${conv.is_group?(conv.members.length+1)+' წევრი':isOnline(other)?'ონლაინ':'ბოლოს იყო '+ago(prof(other).last_seen||Date.now())}</span></div>
 ${other?`<button class="ibtn" data-a="call" data-u="${other}" data-v="0" aria-label="ხმოვანი ზარი">${ic('phone')}</button><button class="ibtn" data-a="call" data-u="${other}" data-v="1" aria-label="ვიდეოზარი">${ic('video')}</button>`:`<button class="ibtn" data-a="gcall" data-c="${cid}" aria-label="ჯგუფური ვიდეოზარი">${ic('video')}</button>`}<button class="ibtn" data-a="chatmore" data-c="${cid}" aria-label="მეტი">${ic('more')}</button></div>
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
  rows.forEach(r=>st.msgs.set(r.id,r));st.more=rows.length===60;cb.innerHTML=rows.length?rows.map(msgHTML).join(''):'<p class="muted" id="chempty">დაწერე პირველი შეტყობინება.</p>';rows.forEach(expire);cb.scrollTop=1e6;loadReacts(st,rows.map(r=>r.id))}catch(e){cb.innerHTML=`<p class="muted">${errMsg(e)}</p>`}
 cb.addEventListener('scroll',()=>{if(cb.scrollTop<160&&st.more&&!st.oldBusy)loadOlder(st)},{passive:true});drawChatSub();
 q(sb.from('conversation_members').select('user_id,seen_at').eq('conv_id',cid)).then(ms=>{if(CHAT!==st)return;ms.forEach(r=>{if(r.user_id!==ME.id)st.seen.set(r.user_id,r.seen_at)});drawSeen()}).catch(()=>{});
 meta();markRead(cid);
 if(matchMedia('(hover:none)').matches&&!store.get('tip:hold',0)){store.set('tip:hold',1);setTimeout(()=>{if(CHAT===st)toast('შეტყობინებას დიდხანს დააჭირე: პასუხი, გადაგზავნა, მიმაგრება')},1200)}
 chan=sb.channel('conv-'+cid).on('postgres_changes',{event:'INSERT',schema:'public',table:'messages',filter:'conv_id=eq.'+cid},async pl=>{const m=pl.new;await loadProfiles([m.sender]);$('#chempty')?.remove();stopTyping(m.sender);add(m);if(m.kind==='system')meta();if(m.sender!==ME.id)markRead(cid)})
  .on('postgres_changes',{event:'UPDATE',schema:'public',table:'conversation_members',filter:'conv_id=eq.'+cid},pl=>{const r=pl.new;if(!r||r.user_id===ME.id)return;st.seen.set(r.user_id,r.seen_at);drawSeen()})
  .on('postgres_changes',{event:'*',schema:'public',table:'message_reactions',filter:'conv_id=eq.'+cid},pl=>{const r=pl.new;if(!r||!r.message_id||r.user_id===ME.id&&st.reacts.get(r.message_id)?.get(ME.id)===r.emoji)return;setReact(st,r.message_id,r.user_id,r.emoji)})
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
 $('#ch_more').onclick=()=>layer(lhead('დამატება')+`<div class="reasons"><button data-a="chimg">${ic('image')} ფოტო</button><button data-a="chloc">${ic('pin')} ჩემი ლოკაცია</button><button data-a="chcard">${ic('card')} მისალოცი ბარათი</button>${CHAT&&CHAT.other?`<button data-a="chgame">${ic('dice')} თამაშზე გამოწვევა</button>`:''}</div>`)}
A.chimg=async()=>{closeLayer();const st=CHAT;if(!st)return;const b=await pickImage({max:ECO()?1080:1600});if(!b)return;try{toast('იტვირთება…');const m=await uploadMedia(b,'image');st.send({kind:'image',media:{url:m.url,sm:m.sm||undefined,w:m.w,h:m.h}})}catch(e){toast(errMsg(e))}};
A.chloc=()=>{closeLayer();const st=CHAT;if(!st)return;if(!navigator.geolocation){toast('ამ მოწყობილობაზე ლოკაცია მიუწვდომელია');return}toast('ლოკაციას ვადგენ…');
 navigator.geolocation.getCurrentPosition(p=>{const{latitude:lat,longitude:lng,accuracy:acc}=p.coords;st.send({body:'📍 ლოკაცია',media:{loc:{lat:+lat.toFixed(6),lng:+lng.toFixed(6),acc:Math.round(acc)}}})},()=>toast('ლოკაციაზე წვდომა არ მოგვეცა. ჩართე ბრაუზერის პარამეტრებში'),{enableHighAccuracy:true,timeout:15000,maximumAge:30000})};
A.chcard=()=>{closeLayer();if(CHAT)openCardPicker({cid:CHAT.cid,uid:CHAT.other||null,kind:'g'})};
function drawPin(){const b=$('#pinb'),st=CHAT;if(!b||!st)return;const m=st.pinned&&(st.msgs.get(st.pinned)||st.pinMsg);b.hidden=!m;if(m)b.innerHTML=`${ic('pin')}<span class="grow"><b>მიმაგრებული</b><span>${esc(snip(m))}</span></span><span class="ibtn sm" data-a="unpin" role="button" aria-label="მოხსნა">${ic('x')}</span>`}
A.jumppin=t=>{if(CHAT?.pinned)jumpTo(CHAT.pinned)};
A.jumpmsg=t=>jumpTo(+t.dataset.mid);
async function jumpTo(id){let el=$(`#cb [data-mid="${id}"]`);const st=CHAT;
 if(!el&&st){toast('ვეძებ…');for(let k=0;k<20&&!el&&st.more&&CHAT===st;k++){await loadOlder(st,true);el=$(`#cb [data-mid="${id}"]`)}}
 if(!el){toast('ეს შეტყობინება აღარ მოიძებნა');return}el.scrollIntoView({block:'center',behavior:RM()?'auto':'smooth'});el.classList.remove('flash');void el.offsetWidth;el.classList.add('flash')}
A.unpin=async(t,e)=>{e?.stopPropagation();const st=CHAT;if(!st)return;try{await rpc('pin_message',{p_conv:st.cid,p_msg:null});st.pinned=null;drawPin()}catch(x){toast(errMsg(x))}};
function setReply(m){const st=CHAT;if(!st)return;st.reply=m;if(m)st.edit=null;const b=$('#rpb');if(!b)return;b.hidden=!m;b.innerHTML=m?`${ic('reply')}<span class="grow"><b>${esc(String(pname(m.sender)).split(' ')[0])}</b><span>${esc(snip(m))}</span></span><button type="button" class="ibtn sm" id="rpx" aria-label="გაუქმება">${ic('x')}</button>`:'';const x=$('#rpx');if(x)x.onclick=()=>{setReply(null);setEdit(null)};if(m)$('#cin')?.focus()}
function setEdit(m){const st=CHAT;if(!st)return;st.edit=m;const b=$('#rpb'),inp=$('#cin');if(m){st.reply=null;b.hidden=false;b.innerHTML=`${ic('edit')}<span class="grow"><b>რედაქტირება</b><span>${esc(snip(m))}</span></span><button type="button" class="ibtn sm" id="rpx" aria-label="გაუქმება">${ic('x')}</button>`;$('#rpx').onclick=()=>{setEdit(null);inp.value=''};inp.value=m.body;inp.focus()}else if(!st.reply){b.hidden=true;b.innerHTML=''}}
A.msgact=t=>{const st=CHAT,m=st&&st.msgs.get(+t.dataset.mid);if(!m)return;const me=m.sender===ME.id,plain=m.kind==='text'&&!m.media?.sticker&&!m.media?.card&&!m.media?.loc&&!m.media?.fwd;
 const canEdit=me&&plain&&Date.now()-new Date(m.created_at)<48*36e5;
 const myR=st.reacts.get(m.id)?.get(ME.id);
 layer(lhead('შეტყობინება')+(m.deleted||m.kind==='system'?'':`<div class="mqr" role="group" aria-label="რეაქცია">${MREACT.map(e=>`<button data-a="mreact" data-mid="${m.id}" data-e="${e}" class="${myR===e?'on':''}" aria-label="${e}">${rg(e)}</button>`).join('')}</div>`)+`<div class="reasons"><button data-a="mreply" data-mid="${m.id}">${ic('reply')} პასუხი</button>${m.body&&plain?`<button data-a="mcopy" data-mid="${m.id}">${ic('note')} კოპირება</button>`:''}<button data-a="mfwd" data-mid="${m.id}">${ic('fwd')} გადაგზავნა</button><button data-a="mpin" data-mid="${m.id}">${ic('pin')} ${st.pinned===m.id?'მიმაგრების მოხსნა':'მიმაგრება'}</button>${canEdit?`<button data-a="medit" data-mid="${m.id}">${ic('edit')} რედაქტირება</button>`:''}${me?`<button class="warnbtn" data-a="munsend" data-mid="${m.id}">${ic('trash')} ყველასთვის წაშლა</button>`:`<button data-a="mreport" data-mid="${m.id}">${ic('flag')} საჩივარი</button>`}</div>`)};
const cm=t=>CHAT&&CHAT.msgs.get(+t.dataset.mid);
A.mreply=t=>{closeLayer();setReply(cm(t))};
A.medit=t=>{closeLayer();setEdit(cm(t))};
A.mcopy=async t=>{closeLayer();try{await navigator.clipboard.writeText(cm(t).body);toast('დაკოპირდა')}catch(e){toast('ვერ დაკოპირდა')}};
A.mpin=async t=>{const m=cm(t),st=CHAT;closeLayer();if(!m||!st)return;const on=st.pinned!==m.id;try{await rpc('pin_message',{p_conv:st.cid,p_msg:on?m.id:null});st.pinned=on?m.id:null;drawPin()}catch(e){toast(errMsg(e))}};
A.munsend=async t=>{const m=cm(t);closeLayer();if(!m)return;try{await rpc('unsend_message',{p_id:m.id});Object.assign(m,{deleted:true,body:'',media:null});redrawMsg(m.id);if(CHAT.pinned===m.id){CHAT.pinned=null;drawPin()}}catch(e){toast(errMsg(e))}};
A.mreport=t=>{const m=cm(t);closeLayer();if(m)A.report({dataset:{type:'message',id:String(m.id)}})};
A.mfwd=async t=>{const m=cm(t);if(!m)return;let list=CONVS;try{if(!list.length)list=CONVS=await myChats();await loadProfiles(list.flatMap(c=>c.members||[]))}catch(e){}
 layer(lhead('ვის გადავუგზავნო?')+`<div class="ph-body">${list.map(c=>{const o=!c.is_group&&c.members?.[0];return `<button class="row" data-a="mfwdto" data-mid="${m.id}" data-c="${c.conv_id}">${c.is_group?`<span class="av gav" style="--s:40px;--h:${(c.conv_id*47)%360}">${ic('users')}</span>`:av(o,40)}<span class="grow"><b>${esc(c.is_group?(c.title||'ჯგუფი'):pname(o))}</b></span>${ic('send')}</button>`}).join('')||'<p class="muted">სხვა მიმოწერა ჯერ არ გაქვს.</p>'}</div>`)};
A.mfwdto=async t=>{const m=cm(t),to=+t.dataset.c;if(!m)return;t.disabled=true;const media=Object.assign({},m.media||{},{fwd:String(pname(m.sender))});
 try{await q(sb.from('messages').insert({conv_id:to,sender:ME.id,body:m.body||'',kind:m.kind==='system'?'text':m.kind,media}));closeLayer();toast('გადაიგზავნა')}catch(e){toast(errMsg(e));t.disabled=false}};
async function markRead(cid){try{await sb.from('conversation_members').update({last_read_at:new Date().toISOString()}).eq('conv_id',cid).eq('user_id',ME.id);const c=CONVS.find(x=>x.conv_id===cid);if(c){S.unreadMsgs=Math.max(0,S.unreadMsgs-(c.unread||0));c.unread=0;renderBadges()}}catch(e){}}
A.imgview=t=>{const u=String(t.dataset.src||'');if(/^https:\/\//i.test(u))openImage(u,{top:true})};
A.chatmore=t=>{const cid=+t.dataset.c,conv=CONVS.find(c=>c.conv_id===cid);const other=conv&&!conv.is_group&&conv.members?.[0];
 sheet(head('საუბარი')+`<div class="reasons"><button data-a="chsearch" data-c="${cid}">${ic('search')} ძებნა საუბარში</button><button data-a="chmedia" data-c="${cid}">${ic('image')} ფოტოები და ბმულები</button><button data-a="chmute" data-c="${cid}">${ic('mute')} ${mutedNow(conv)?'ხმის ჩართვა':'დადუმება'}</button><button data-a="charch" data-c="${cid}">${ic('archive')} ${conv?.archived?'არქივიდან ამოღება':'არქივში გადატანა'}</button><button data-a="chttl" data-c="${cid}">${ic('timer')} თვითგაქრობადი შეტყობინებები</button>${conv?.is_group?`<button data-a="gcmembers" data-c="${cid}">წევრები</button><button data-a="gcadd" data-c="${cid}">წევრის დამატება</button><button data-a="gcrename" data-c="${cid}">სახელის შეცვლა</button><button class="warnbtn" data-a="gcleave" data-c="${cid}">ჯგუფიდან გასვლა</button>`:other?`<button data-a="user" data-u="${other}">პროფილის ნახვა</button><button data-a="report" data-type="user" data-id="${other}">საჩივარი</button><button class="warnbtn" data-a="block" data-u="${other}">დაბლოკვა</button>`:''}</div>`,'short')};
A.chttl=async t=>{const cid=+t.dataset.c;let cur=null;try{cur=(await q(sb.from('conversations').select('ttl').eq('id',cid).maybeSingle()))?.ttl||null}catch(e){}
 sheet(head('თვითგაქრობა')+`<p class="hint" style="padding:12px 16px 0">ჩართვის შემდეგ ახალი შეტყობინებები ორივე მხარეს თავისით გაქრება. ეკრანის სურათს ეს ვერ შეაჩერებს.</p><div class="reasons">${[[null,'გამორთული'],[3600,'1 საათში'],[86400,'24 საათში'],[604800,'7 დღეში']].map(([v,l])=>`<button data-a="setttl" data-c="${cid}" data-v="${v||''}"${v===cur?' aria-pressed="true"':''}>${v===cur?ic('check')+' ':''}${l}</button>`).join('')}</div>`,'short')};
A.setttl=async t=>{const cid=+t.dataset.c,v=t.dataset.v?+t.dataset.v:null;try{await rpc('set_chat_ttl',{p_conv:cid,p_ttl:v});toast(v?'თვითგაქრობა ჩაირთო':'თვითგაქრობა გამოირთო');openChat(cid)}catch(e){toast(errMsg(e))}};
/* a video call for the whole group chat: everyone in it gets a card to join */
A.gcall=async t=>{const cid=+t.dataset.c;try{const id=await rpc('start_group_call',{p_conv:cid});openPage('room',id)}catch(e){toast(errMsg(e))}};
A.joincall=t=>openPage('room',+t.dataset.r);
function friendPicker(title,okLabel,cb,exclude=new Set()){const ids=[...FRIENDS].filter(i=>!exclude.has(i));
 sheet(head(title)+`<div class="ph-body">${cb.withTitle?'<label class="fld">ჯგუფის სახელი<input id="gct" maxlength="80" placeholder="მაგ. სუფრის ბიჭები"></label>':''}${ids.map(id=>`<label class="row pick"><input type="checkbox" value="${id}">${av(id,40)}<span class="grow"><b>${esc(pname(id))}</b></span></label>`).join('')||'<p class="muted">მეგობრები ჯერ არ გყავს.</p>'}</div><div class="ph-foot"><span class="sp"></span><button class="btn" id="pk_ok">${okLabel}</button></div>`);
 $('#pk_ok').onclick=async()=>{const sel=$$('.pick input:checked',$('#sheet')).map(i=>i.value);if(!sel.length){toast('აირჩიე მინიმუმ ერთი მეგობარი');return}try{await cb(sel,$('#gct')?.value||'')}catch(e){toast(errMsg(e))}}}
A.newgroupchat=()=>{const f=async(sel,title)=>{const c=await rpc('create_group_chat',{p_title:title,p_members:sel});CONVS=await myChats();openChat(c)};f.withTitle=1;friendPicker('ახალი ჯგუფური ჩატი','შექმნა',f)};
A.gcadd=t=>{const cid=+t.dataset.c,conv=CONVS.find(c=>c.conv_id===cid);friendPicker('წევრის დამატება','დამატება',async sel=>{await rpc('add_to_group_chat',{c:cid,p_members:sel});CONVS=await myChats();toast('დაემატა');openChat(cid)},new Set(conv?.members||[]))};
A.gcmembers=t=>{const conv=CONVS.find(c=>c.conv_id===+t.dataset.c);sheet(head('წევრები')+`<div class="ph-body">${personRow(ME)}${(conv?.members||[]).map(id=>personRow(prof(id))).join('')}</div>`)};
A.gcrename=t=>{const cid=+t.dataset.c;sheet(head('სახელის შეცვლა')+`<form class="ph-body" id="gcr"><input class="field sq" id="gcn" maxlength="80" required></form><div class="ph-foot"><span class="sp"></span><button class="btn" id="gcok">შენახვა</button></div>`,'short');$('#gcok').onclick=async()=>{try{await q(sb.from('conversations').update({title:$('#gcn').value.trim()}).eq('id',cid));CONVS=await myChats();openChat(cid)}catch(e){toast(errMsg(e))}}};
A.gcleave=t=>{const cid=+t.dataset.c;confirmSheet('ჯგუფიდან გასვლა','ამ ჯგუფის შეტყობინებებს აღარ მიიღებ.','გასვლა',async()=>{await q(sb.from('conversation_members').delete().eq('conv_id',cid).eq('user_id',ME.id));CONVS=CONVS.filter(c=>c.conv_id!==cid)},true)};
/* hold a message for its menu: right click on a computer, a long press on a phone (iOS has no contextmenu event) */
let LP=null;
document.addEventListener('contextmenu',e=>{const row=e.target.closest('#cb .mrow');if(!row||e.target.closest('a,audio,video'))return;e.preventDefault();if(LP&&LP.fired&&Date.now()-LP.fired<1200)return;A.msgact({dataset:{mid:row.dataset.mid}})});
document.addEventListener('pointerdown',e=>{if(e.pointerType==='mouse')return;const row=e.target.closest('#cb .mrow,#chl .row[data-c]');if(!row||e.target.closest('a,audio,video,button.mact,.mreact')||!(row.dataset.mid||row.dataset.c))return;
 clearTimeout(LP?.t);LP={x:e.clientX,y:e.clientY,row,t:setTimeout(()=>{if(!LP||LP.row!==row)return;LP.fired=Date.now();try{navigator.vibrate&&navigator.vibrate(12)}catch(x){}row.classList.add('held');setTimeout(()=>row.classList.remove('held'),260);if(row.dataset.mid)A.msgact({dataset:{mid:row.dataset.mid}});else A.chatmenu({dataset:{c:row.dataset.c}})},480)}},{passive:true});
document.addEventListener('contextmenu',e=>{const row=e.target.closest('#chl .row[data-c]');if(!row)return;e.preventDefault();if(LP&&LP.fired&&Date.now()-LP.fired<1200)return;A.chatmenu({dataset:{c:row.dataset.c}})});
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

/* reactions */
async function loadReacts(st,ids){if(!ids.length)return;try{const rows=await q(sb.from('message_reactions').select('message_id,user_id,emoji').eq('conv_id',st.cid).not('emoji','is',null).in('message_id',ids.slice(0,300)));if(CHAT!==st)return;
 const touched=new Set();rows.forEach(r=>{if(!st.reacts.has(r.message_id))st.reacts.set(r.message_id,new Map());st.reacts.get(r.message_id).set(r.user_id,r.emoji);touched.add(r.message_id)});await loadProfiles(rows.map(r=>r.user_id));touched.forEach(id=>redrawMsg(id))}catch(e){}}
function setReact(st,mid,uid,emoji){if(!st.reacts.has(mid))st.reacts.set(mid,new Map());const r=st.reacts.get(mid);if(emoji)r.set(uid,emoji);else r.delete(uid);if(CHAT===st){redrawMsg(mid);if(emoji&&uid!==ME.id){const b=$(`#cb [data-mid="${mid}"] .mreact`);if(b)pop(b)}}}
async function reactTo(mid,emoji){const st=CHAT,m=st&&st.msgs.get(mid);if(!m||m.deleted)return;const cur=st.reacts.get(mid)?.get(ME.id)||null,next=cur===emoji?null:emoji;setReact(st,mid,ME.id,next);
 try{if(!cur&&next)await q(sb.from('message_reactions').upsert({message_id:mid,user_id:ME.id,emoji:next},{onConflict:'message_id,user_id'}));else await q(sb.from('message_reactions').update({emoji:next}).eq('message_id',mid).eq('user_id',ME.id))}
 catch(e){if(/duplicate|conflict/i.test(e.message||'')){try{await q(sb.from('message_reactions').update({emoji:next}).eq('message_id',mid).eq('user_id',ME.id))}catch(x){setReact(st,mid,ME.id,cur);toast(errMsg(x))}}else{setReact(st,mid,ME.id,cur);toast(errMsg(e))}}}
A.mreact=t=>{closeLayer();reactTo(+t.dataset.mid,t.dataset.e)};
A.mreacts=t=>{const st=CHAT,r=st?.reacts.get(+t.dataset.mid);if(!r||!r.size)return;
 layer(lhead('რეაქციები')+`<div class="ph-body" style="padding-top:6px"><div class="list">${[...r.entries()].map(([u,e])=>`<button class="row" data-a="user" data-u="${u}">${av(u,40)}<span class="grow"><b>${esc(u===ME.id?'შენ':pname(u))}</b>${u===ME.id?'<span class="sub">შეეხე მოსაშორებლად</span>':''}</span><span class="rxe">${rg(e)}</span></button>`).join('')}</div></div>`);
 $$('#layer .row').forEach(b=>{if(b.dataset.u===ME.id){b.dataset.a='';b.onclick=()=>{closeLayer();reactTo(+t.dataset.mid,r.get(ME.id))}}})};
document.addEventListener('dblclick',e=>{const row=e.target.closest('#cb .mrow');if(!row||!row.dataset.mid||e.target.closest('a,audio,video,button'))return;e.preventDefault();const mid=+row.dataset.mid;reactTo(mid,'❤️')});
/* older messages, a page at a time, keeping the scroll position */
async function loadOlder(st,quiet){if(!st||st.oldBusy||!st.more)return;st.oldBusy=true;const cb=$('#cb');
 try{const first=[...st.msgs.values()].filter(m=>!m._old).sort((a,b)=>new Date(a.created_at)-new Date(b.created_at))[0];if(!first){st.more=false;return}
  const rows=await q(sb.from('messages').select(MSEL).eq('conv_id',st.cid).lt('created_at',first.created_at).order('created_at',{ascending:false}).limit(60));if(CHAT!==st||!cb)return;
  st.more=rows.length===60;rows.reverse();await loadProfiles(rows.map(r=>r.sender));const fresh=rows.filter(r=>{const o=st.msgs.get(r.id);return !o||o._old});fresh.forEach(r=>st.msgs.set(r.id,r));
  const h=cb.scrollHeight,top=cb.scrollTop;fresh.forEach(r=>$(`#cb [data-mid="${r.id}"]`)?.remove());cb.insertAdjacentHTML('afterbegin',fresh.map(msgHTML).join(''));cb.scrollTop=top+(cb.scrollHeight-h);loadReacts(st,fresh.map(r=>r.id))}
 catch(e){if(!quiet)toast(errMsg(e))}finally{st.oldBusy=false}}
function drawChatSub(){const st=CHAT,b=$('#sheet .ph-head .grow>b');if(!st||!b)return;b.querySelector('.chmu')?.remove();if(mutedNow(st.conv)||mutedNow(CONVS.find(c=>c.conv_id===st.cid)))b.insertAdjacentHTML('beforeend',`<i class="chmu" aria-label="დადუმებულია">${ic('mute')}</i>`)}
/* search inside one chat */
A.chsearch=t=>{const cid=+t.dataset.c;
 layer(lhead('ძებნა საუბარში')+`<form class="ph-body" id="chsf" style="gap:10px"><input class="field" id="chsq" type="search" maxlength="60" placeholder="რას ეძებ?" aria-label="ძებნა" autocomplete="off"><div id="chsr" class="list"></div></form>`);
 const inp=$('#chsq'),out=$('#chsr');let tm;setTimeout(()=>inp.focus(),120);
 const go=async()=>{const v=inp.value.trim();if(v.length<2){out.innerHTML='<p class="note">ჩაწერე მინიმუმ 2 ასო.</p>';return}out.innerHTML=skel(2);
  try{const rows=await q(sb.from('messages').select('id,sender,body,created_at,kind').eq('conv_id',cid).eq('deleted',false).ilike('body',`%${v.replace(/[%_\\]/g,m=>'\\'+m)}%`).order('created_at',{ascending:false}).limit(40));await loadProfiles(rows.map(r=>r.sender));if(inp.value.trim()!==v)return;
   const hl=txt=>{const s0=String(txt||''),i=s0.toLowerCase().indexOf(v.toLowerCase());const from=Math.max(0,i-30),part=s0.slice(from,from+120);const j=part.toLowerCase().indexOf(v.toLowerCase());return (from?'…':'')+(j<0?esc(part):esc(part.slice(0,j))+'<mark>'+esc(part.slice(j,j+v.length))+'</mark>'+esc(part.slice(j+v.length)))};
   out.innerHTML=rows.map(r=>`<button type="button" class="row" data-a="chjump" data-mid="${r.id}">${av(r.sender,36)}<span class="grow"><b>${esc(r.sender===ME.id?'შენ':pname(r.sender))} <span class="muted" style="font-weight:400;font-size:12px">${ago(r.created_at)}</span></b><span class="sub">${hl(r.body)}</span></span></button>`).join('')||'<p class="note">ვერაფერი მოიძებნა.</p>'}catch(e){out.innerHTML=`<p class="note">${errMsg(e)}</p>`}};
 inp.oninput=()=>{clearTimeout(tm);tm=setTimeout(go,300)};$('#chsf').onsubmit=e=>{e.preventDefault();go()}};
A.chjump=t=>{closeLayer();const mid=+t.dataset.mid;if(CHAT)jumpTo(mid);else closeSheet()};
/* photos, links and places shared in a chat */
A.chmedia=async t=>{const cid=+t.dataset.c;layer(lhead('ფოტოები და ბმულები')+`<div class="seg flat chmt" role="tablist" style="margin:10px 16px 0">${[['img','ფოტოები'],['link','ბმულები'],['loc','ლოკაციები']].map(([k,l],i)=>`<button data-a="chmtab" data-k="${k}" aria-pressed="${!i}">${l}</button>`).join('')}</div><div class="ph-body" id="chmb">${skel(2)}</div>`);
 try{const[imgs,links,locs]=await Promise.all([q(sb.from('messages').select('id,media,created_at').eq('conv_id',cid).eq('kind','image').eq('deleted',false).order('created_at',{ascending:false}).limit(150)),
   q(sb.from('messages').select('id,sender,body,media,created_at').eq('conv_id',cid).eq('deleted',false).ilike('body','%http%').order('created_at',{ascending:false}).limit(80)),
   q(sb.from('messages').select('id,sender,media,created_at').eq('conv_id',cid).eq('deleted',false).not('media->loc','is',null).order('created_at',{ascending:false}).limit(40))]);
  A.chmedia.data={imgs:imgs.filter(m=>safeU(m.media?.url)),links,locs};A.chmtab({dataset:{k:'img'}})}catch(e){const b=$('#chmb');if(b)b.innerHTML=`<p class="note">${errMsg(e)}</p>`}};
A.chmtab=t=>{const d=A.chmedia.data,b=$('#chmb'),k=t.dataset.k;if(!b||!d)return;$$('#layer .chmt button').forEach(x=>x.setAttribute('aria-pressed',String(x.dataset.k===k)));
 if(k==='img')b.innerHTML=d.imgs.length?`<div class="chgrid">${d.imgs.map(m=>`<button data-a="chmimg" data-src="${esc(m.media.url)}" aria-label="ფოტოს გახსნა"><img src="${esc(mSm(m.media))}" alt="" loading="lazy"></button>`).join('')}</div>`:'<p class="note">ამ საუბარში ფოტოები ჯერ არ არის.</p>';
 else if(k==='link'){const rows=d.links.map(m=>({m,u:(String(m.body||'').match(/https?:\/\/[^\s<]+/)||[])[0]})).filter(x=>x.u&&safeU(x.u));
  b.innerHTML=rows.length?`<div class="list">${rows.map(({m,u})=>`<a class="row" href="${esc(u)}" target="_blank" rel="noopener noreferrer">${m.media?.link?.image&&safeU(m.media.link.image)?`<img class="lkimg" src="${esc(m.media.link.image)}" alt="" loading="lazy">`:`<span class="lkimg">${ic('share')}</span>`}<span class="grow"><b>${esc(m.media?.link?.title||u.replace(/^https?:\/\//,'').slice(0,60))}</b><span class="sub">${esc(m.sender===ME.id?'შენ':pname(m.sender))} · ${fdate(m.created_at)}</span></span></a>`).join('')}</div>`:'<p class="note">ბმულები ჯერ არ არის.</p>'}
 else b.innerHTML=d.locs.length?d.locs.map(m=>locCard(m.media.loc)+`<p class="note" style="margin:-6px 0 8px">${esc(m.sender===ME.id?'შენ':pname(m.sender))} · ${fdate(m.created_at)}</p>`).join(''):'<p class="note">ლოკაციები ჯერ არ არის.</p>'};
A.chmimg=t=>{const u=t.dataset.src;closeLayer();openImage(u,{top:true})};
