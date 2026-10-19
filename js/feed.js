/* posts: loading, rendering, reactions, polls, comments, composer */
const POSTSEL='id,author,body,media,poll,tags,group_id,page_id,is_clip,hidden,created_at,link,draft,publish_at,edited_at,repost_of,place_id,pending,ap:profiles!posts_author_fkey(id,name,username,avatar_url,hue,verified,is_business),page:pages!posts_page_id_fkey(id,name,hue,avatar_url,verified,kind),grp:groups!posts_group_id_fkey(id,name),pl:places!posts_place_id_fkey(id,name,kind,city)';
const POSTS=new Map(),STAT=new Map(),RS=new Map();
const EMOJI=['👍','❤️','😂','😮','😢','😡','🍷'];
const blankStat=id=>({post_id:id,reactions:{},my_reaction:null,comments:0,grade_avg:null,grade_n:0,my_grade:null,votes:{},my_vote:null,saved:false});
const keepPost=p=>{if(p.ap)PC.set(p.ap.id,Object.assign(PC.get(p.ap.id)||{},p.ap));POSTS.set(p.id,p)};
/* reposts bring their original along; stats are loaded for both */
async function hydrate(rows){rows=rows||[];rows.forEach(keepPost);
 const miss=[...new Set(rows.map(p=>p.repost_of).filter(id=>id&&!POSTS.has(id)))];let orig=[];
 if(miss.length){try{orig=await q(sb.from('posts').select(POSTSEL).in('id',miss));orig.forEach(keepPost)}catch(e){}}
 const ids=[...new Set([...rows.map(p=>p.id),...orig.map(p=>p.id),...rows.map(p=>p.repost_of).filter(Boolean)])];
 if(ids.length){await Promise.all([rpc('feed_stats',{p_ids:ids}).then(st=>st.forEach(s=>STAT.set(s.post_id,s))).catch(()=>{}),rpc('repost_stats',{p_ids:ids}).then(st=>st.forEach(s=>RS.set(s.post_id,s))).catch(()=>{})])}
 return rows}
async function fetchPosts(build){return hydrate(await q(build(sb.from('posts').select(POSTSEL).eq('draft',false).lte('created_at',new Date(Date.now()+3e5).toISOString()))))}
const LOCALHIDE=store.get('hidden',{});
const rTotal=s=>Object.values(s.reactions||{}).reduce((a,b)=>a+b,0);
const rTop=s=>Object.entries(s.reactions||{}).sort((a,b)=>b[1]-a[1]).slice(0,3).map(e=>rg(e[0])).join('');
function pollBlock(p,s){if(!p.poll||!Array.isArray(p.poll.opts))return '';const tot=Object.values(s.votes||{}).reduce((a,b)=>a+b,0),voted=s.my_vote!=null;
 return `<div class="poll" role="group" aria-label="გამოკითხვა"><b>${esc(p.poll.q)}</b>${p.poll.opts.map((o,i)=>{const n=s.votes?.[i]||0,pc=tot?Math.round(n/tot*100):0;return `<button class="popt${s.my_vote===i?' mine':''}" data-a="vote" data-pid="${p.id}" data-i="${i}"${voted?` style="--pc:${pc}%"`:''}><span>${esc(o)}</span>${voted?`<em>${pc}%</em>`:''}</button>`}).join('')}<span class="note">${tot} ხმა${voted?'':' · აირჩიე პასუხი'}</span></div>`}
/* the photo keeps its own shape: the card follows it (between 4:5 and 1.91:1) and anything left over is plain background */
const boxRatio=m=>{const w=+(m&&m.w),h=+(m&&m.h);if(!(w>0&&h>0))return 1;return Math.round(Math.min(1.91,Math.max(.8,w/h))*1000)/1000};
/* older photos have no saved size: the frame takes the photo's shape once it has loaded */
document.addEventListener('load',e=>{const im=e.target;if(!im||im.tagName!=='IMG')return;const box=im.closest('.pmmedia[data-fit]');if(!box||im.closest('.pmi')?.dataset.i!=='0'||!im.naturalWidth)return;box.removeAttribute('data-fit');box.style.setProperty('--ar',boxRatio({w:im.naturalWidth,h:im.naturalHeight}))},true);
/* a post: photos and videos fill the card with the author on top and grading and actions at the bottom, the caption sits underneath */
const pmedia=p=>(Array.isArray(p.media)?p.media:[]).filter(m=>m&&/^https?:|^data:/.test(String(m.url||'')));
function whoHTML(p,u,pg){const tags=`${p.grp?`<button class="ptag" data-a="group" data-id="${p.grp.id}">${esc(p.grp.name)}</button>`:''}${p.pl?`<button class="ptag plc" data-a="page" data-p="place" data-arg="${p.pl.id}">📍 ${esc(p.pl.name)}</button>`:''}${p.hidden?'<span class="ptag warn">დამალულია</span>':''}${p.pending?'<span class="ptag warn">ელოდება დამტკიცებას</span>':''}${p.ad?'<span class="ptag ad">რეკლამა</span>':''}`;
 return pg?`<button class="pwho" data-a="pagev" data-id="${pg.id}" aria-label="${esc(pg.name)}">${avAny({n:pg.name,h:pg.hue,u:pg.avatar_url},38).replace('class="av"','class="av sq"')}</button><span class="pwt"><span class="pwn"><button class="pname" data-a="pagev" data-id="${pg.id}"><b>${esc(pg.name)}${pg.verified?vb({verified:1}):''}</b></button><span class="ptag">${pg.kind==='business'?'ბიზნესი':'არხი'}</span>${tags}</span><span class="pwtime">${ago(p.created_at)}${p.edited_at?' · რედაქტირებული':''}</span></span>`
  :`<button class="pwho" data-a="user" data-u="${u.id}" aria-label="${esc(u.name)}">${av(u,38)}</button><span class="pwt"><span class="pwn"><button class="pname" data-a="user" data-u="${u.id}"><b>${esc(u.name)}${vb(u)}</b></button>${tags}</span><span class="pwtime">${ago(p.created_at)}${p.edited_at?' · რედაქტირებული':''}</span></span>`}
/* grading: only for photos, never for your own post (you still see the average) */
function gradeHTML(p,s){if(!pmedia(p).some(x=>x.type==='image'))return '';const sum=s.grade_n?`<em>საშ. ${s.grade_avg} · ${s.grade_n}</em>`:'';
 if(p.author===ME.id)return sum?`<div class="grade mine"><span>შეფასება</span>${sum}</div>`:'';
 return `<div class="grade" role="group" aria-label="ფოტოს შეფასება"><span>შეფასება</span>${['1','2','3','4','5','5+'].map(x=>`<button data-a="grade" data-g="${x}" class="${x==='5+'?'plus':''}${s.my_grade===x?' on':''}">${x}</button>`).join('')}${sum}</div>`}
function actsHTML(p,s){const m=s.my_reaction;
 return `<div class="acts"><div class="rwrap"><button class="act${m?' on':''}" data-a="react" aria-label="რეაქცია">${m?`<span class="em">${rg(m)}</span>`:ic('heart')}<span>${rTotal(s)||''}</span></button></div>
 <button class="act" data-a="comments" aria-label="კომენტარები">${ic('comment')}<span>${s.comments||''}</span></button>
 <button class="act${RS.get(p.id)?.mine?' on':''}" data-a="share" aria-label="გაზიარება">${ic(RS.get(p.id)?.mine?'repost':'send')}<span>${RS.get(p.id)?.n||''}</span></button>
 <button class="act${s.saved?' on':''}" data-a="save" aria-label="${s.saved?'შენახულია':'შენახვა'}">${ic('bookmark',s.saved?'currentColor':'')}</button>
 <span class="rsum" aria-hidden="true">${rTop(s)}</span><button class="act" data-a="pmore" aria-label="მეტი მოქმედება">${ic('more')}</button></div>`}
/* the caption folds when it is long and opens with "სრულად" */
function descHTML(p,lines){const b=String(p.body||'');if(!b.trim())return '';const long=b.length>(lines>3?320:110)||(b.match(/\n/g)||[]).length>=lines;
 return `<div class="pdesc${long?' clamp':''}" style="--l:${lines}">${tx(b)}${long?'<button class="pmore2" data-a="pmore2">სრულად</button>':''}</div>`}
A.pmore2=t=>{const d=t.closest('.pdesc');if(!d)return;const open=!d.classList.contains('open');d.classList.toggle('open',open);t.textContent=open?'მოკლედ':'სრულად'};
function mediaTile(m,i,p){const alt=p.body?esc(String(p.body).slice(0,80)):'';
 return `<button class="pmi" data-a="pmtap" data-pid="${p.id}" data-i="${i}" aria-label="${m.type==='video'?'ვიდეოს გახსნა':'ფოტოს გახსნა'}">${m.type==='video'?`<video src="${esc(m.url)}"${mPoster(m)?` poster="${esc(mPoster(m))}" preload="none"`:' preload="metadata"'} muted playsinline></video><span class="pmplay">${ic('clips')}</span>`:`<img src="${esc(mMd(m))}" alt="${alt}" loading="lazy" decoding="async"${m.w&&m.h?` width="${+m.w|0}" height="${+m.h|0}"`:''}>`}</button>`}
/* a plain repost shows the original under a "shared" line; a quote is the sharer's own post with the original as a card */
function quoteHTML(o,still){if(!o)return `<div class="qcard gone">${ic('repost')}ეს პოსტი აღარ არის ხელმისაწვდომი</div>`;const u=o.page?{name:o.page.name,hue:o.page.hue}:(o.ap||prof(o.author)),m=pmedia(o)[0];
 const tag=still?'div':'button';
 return `<${tag} class="qcard"${still?'':` data-a="qopen" data-pid="${o.id}" aria-label="${esc(u.name)}-ის პოსტის გახსნა"`}>${m?`<span class="qimg">${m.type==='video'?(mPoster(m)?`<img src="${esc(mPoster(m))}" alt="" loading="lazy">`:'')+`<i>${ic('clips')}</i>`:`<img src="${esc(mSm(m))}" alt="" loading="lazy">`}</span>`:''}<span class="qtx"><span class="qwho">${o.page?avAny({n:o.page.name,h:o.page.hue},22):av(u,22)}<b>${esc(u.name)}</b><small>${ago(o.created_at)}</small></span>${o.body?`<span class="qb">${esc(String(o.body).slice(0,220))}</span>`:o.poll?`<span class="qb">📊 ${esc(o.poll.q||'')}</span>`:''}</span></${tag}>`}
A.qopen=t=>{const id=+t.dataset.pid;if(POSTS.has(id))openPV(id);else openPage("post",id)};
function postHTML(p){if(p.repost_of&&!String(p.body||'').trim()){const o=POSTS.get(p.repost_of);if(!o)return '';const ru=p.ap||prof(p.author);
  return `<div class="rpw" data-rid="${p.id}" data-orig="${o.id}"><div class="rphead">${ic('repost')}<button class="pname" data-a="user" data-u="${ru.id}">${esc(ru.id===ME.id?'შენ':ru.name)}</button><span>${ru.id===ME.id?'გააზიარე':'გააზიარა'} · ${ago(p.created_at)}</span>${ru.id===ME.id?`<button class="ibtn sm" data-a="unrepost" data-rid="${p.id}" data-pid="${o.id}" aria-label="რეპოსტის გაუქმება">${ic('x')}</button>`:''}</div>${postHTML(o)}</div>`}
 const s=STAT.get(p.id)||blankStat(p.id),u=p.ap||prof(p.author),pg=p.page,media=pmedia(p);
 const cls=`post${p.hidden?' is-hidden':''}`;
 if(media.length&&!(ECO()&&!p._eco)){const n=media.length;
  return `<article class="${cls} pm" data-id="${p.id}"><div class="pmw${n>1?' multi':''}">
   <div class="pmtop">${whoHTML(p,u,pg)}${n>1?`<span class="pmcount" aria-hidden="true"><b>1</b>/${n}</span>`:''}</div>
   <div class="pmmedia" style="--ar:${boxRatio(media[0])}"${media[0]&&+media[0].w>0&&+media[0].h>0?'':' data-fit'}><div class="pmtrack">${media.map((m,i)=>mediaTile(m,i,p)).join('')}</div>
   ${n>1?`<button class="pmnav prev" data-a="pmnav" data-d="-1" aria-label="წინა">${ic('back')}</button><button class="pmnav next" data-a="pmnav" data-d="1" aria-label="შემდეგი">${ic('back')}</button>`:''}
   <span class="burst">${ic('heart','currentColor')}</span></div>
   <div class="pmbot">${n>1?`<div class="pmdots" aria-hidden="true">${media.map((_,i)=>`<i${i?'':' class="on"'}></i>`).join('')}</div>`:''}${gradeHTML(p,s)}${actsHTML(p,s)}</div></div>
   ${descHTML(p,2)}${pollBlock(p,s)}</article>`}
 return `<article class="${cls} pc" data-id="${p.id}"><div class="pchead">${whoHTML(p,u,pg)}</div>
  ${media.length?`<button class="ecoimg" data-a="ecopost" data-pid="${p.id}">${ic(media.some(x=>x.type==='video')?'clips':'image')}<span>${media.length>1?media.length+' ფაილი':media[0].type==='video'?'ვიდეო':'ფოტო'} · დააჭირე ჩასატვირთად</span></button>`:''}
  ${descHTML(p,6)}${p.repost_of?quoteHTML(POSTS.get(p.repost_of)):''}${p.link&&!media.length&&!p.repost_of?linkCard(p.link):''}${pollBlock(p,s)}${gradeHTML(p,s)}${actsHTML(p,s)}</article>`}
const pidOf=t=>+(t.dataset.pid||t.closest('.post,[data-pv]')?.dataset.id||t.closest('[data-pv]')?.dataset.pv);
function rerenderPost(id){$$(`.post[data-id="${id}"]`).forEach(el=>{const p=POSTS.get(id);if(!p)return;const tr=$('.pmtrack',el),x=tr?tr.scrollLeft:0;el.outerHTML=postHTML(p);if(x){const n=$(`.post[data-id="${id}"] .pmtrack`);if(n){n.scrollLeft=x;pmSync(n)}}});if(PV&&PV.id===id)refreshPV()}
/* carousel: counter, dots and arrows follow the swipe */
function pmSync(tr){const w=tr.clientWidth||1,i=Math.round(tr.scrollLeft/w),box=tr.closest('.pmw,.pvframe');if(!box)return;const c=$('.pmcount b,.pvcount b',box);if(c)c.textContent=i+1;$$('.pmdots i,.pvdots i',box).forEach((d,k)=>d.classList.toggle('on',k===i));if(box.classList.contains('pvframe')&&PV)PV.i=i}
document.addEventListener('scroll',e=>{const t=e.target;if(t&&t.classList&&(t.classList.contains('pmtrack')||t.classList.contains('pvtrack'))){clearTimeout(t._st);t._st=setTimeout(()=>pmSync(t),60)}},true);
A.pmnav=t=>{const tr=$('.pmtrack,.pvtrack',t.closest('.pmw,.pvframe'));if(tr)tr.scrollBy({left:(+t.dataset.d)*tr.clientWidth,behavior:RM()?'auto':'smooth'})};
/* one tap opens the photo, two taps like it */
A.pmtap=t=>{const id=pidOf(t),i=+t.dataset.i||0,now=Date.now(),T=A.pmtap;
 if(T.id===id&&now-(T.l||0)<300){clearTimeout(T.t);T.l=0;const b=$('.burst',t.closest('.pmw'));if(b){b.classList.remove('go');void b.offsetWidth;b.classList.add('go')}const s=STAT.get(id);if(!s||s.my_reaction!=='❤️')setTimeout(()=>setReaction(id,'❤️'),450);return}
 T.id=id;T.l=now;clearTimeout(T.t);T.t=setTimeout(()=>{T.l=0;openPV(id,i)},290)};

/* the post viewer: rises from below, a fixed black frame, author above and actions below the photo */
let PV=null;
function openPV(id,i=0){const p=POSTS.get(id);if(!p)return;PV={id,i};let el=$('#pv');if(el)el.classList.remove('top');
 if(!el){el=document.createElement('div');el.id='pv';el.className='pv';el.setAttribute('role','dialog');el.setAttribute('aria-modal','true');el.setAttribute('aria-label','პოსტი');document.body.appendChild(el);el.addEventListener('click',e=>{if(e.target===el)closePV()})}
 const s=STAT.get(id)||blankStat(id),u=p.ap||prof(p.author),media=pmedia(p),n=media.length;
 el.classList.remove('closing');el.hidden=false;navMark('pv',()=>openPV(id,PV&&PV.id===id?PV.i:i));navOpen('pv');
 el.innerHTML=`<div class="pvin" data-pv="${p.id}"><div class="pvtop">${whoHTML(p,u,p.page)}<button class="ibtn" data-a="pvclose" aria-label="დახურვა">${ic('x')}</button></div>
  <div class="pvframe${n?'':' text'}">${n?`<div class="pvtrack">${media.map(m=>`<div class="pvs">${m.type==='video'?`<video src="${esc(m.url)}"${mPoster(m)?` poster="${esc(mPoster(m))}"`:''} controls playsinline preload="metadata"></video>`:`<img src="${esc(m.url)}" alt="" decoding="async">`}</div>`).join('')}</div>${n>1?`<span class="pvcount"><b>${i+1}</b>/${n}</span><button class="pmnav prev" data-a="pmnav" data-d="-1" aria-label="წინა">${ic('back')}</button><button class="pmnav next" data-a="pmnav" data-d="1" aria-label="შემდეგი">${ic('back')}</button><div class="pvdots">${media.map((_,k)=>`<i${k===i?' class="on"':''}></i>`).join('')}</div>`:''}`
   :`<div class="pvtext" style="--h:${(u.hue??200)%360}">${tx(p.body)}</div>`}</div>
  <div class="pvbot">${gradeHTML(p,s)}${actsHTML(p,s)}</div>
  <div class="pvdesc">${n&&p.body?tx(p.body):''}${pollBlock(p,s)}${p.link&&!n?linkCard(p.link):''}<button class="btn sm ghost" data-a="comments">${ic('comment')}კომენტარები${s.comments?' · '+s.comments:''}</button></div></div>`;
 const tr=$('.pvtrack',el);if(tr&&i)requestAnimationFrame(()=>{tr.scrollLeft=i*tr.clientWidth});
 document.documentElement.classList.add('pvopen');$$('.pmi video').forEach(v=>{try{v.pause()}catch(e){}})}
function refreshPV(){const el=$('#pv');if(!el||el.hidden||!PV)return;const p=POSTS.get(PV.id);if(!p)return;const s=STAT.get(p.id)||blankStat(p.id);const b=$('.pvbot',el);if(b)b.innerHTML=gradeHTML(p,s)+actsHTML(p,s);const c=$('.pvdesc>[data-a="comments"]',el);if(c)c.innerHTML=`${ic('comment')}კომენტარები${s.comments?' · '+s.comments:''}`;const pl=$('.pvdesc .poll',el);if(pl)pl.outerHTML=pollBlock(p,s)}
function closePV(nav){const el=$('#pv');if(!el||el.hidden)return;if(!nav)navKill('pv');PV=null;setTimeout(()=>el.classList.remove('top'),240);$$('video',el).forEach(v=>{try{v.pause()}catch(e){}});document.documentElement.classList.remove('pvopen');
 if(RM()){el.hidden=true;el.innerHTML='';return}el.classList.add('closing');setTimeout(()=>{if(el.classList.contains('closing')){el.hidden=true;el.innerHTML='';el.classList.remove('closing')}},220)}
A.pvclose=()=>closePV();
A.pvopen=t=>openPV(pidOf(t),+t.dataset.i||0);
/* a single picture, e.g. someone's profile photo */
function openImage(url,opt={}){if(!/^https?:|^data:/.test(String(url||'')))return;let el=$('#pv');if(!el){el=document.createElement('div');el.id='pv';el.className='pv';el.setAttribute('role','dialog');el.setAttribute('aria-modal','true');document.body.appendChild(el);el.addEventListener('click',e=>{if(e.target===el)closePV()})}
 PV={id:null,i:0};el.classList.remove('closing');el.classList.toggle('top',!!opt.top);el.hidden=false;navOpen('pv');el.innerHTML=`<div class="pvin"><div class="pvtop"><span class="grow"></span><button class="ibtn" data-a="pvclose" aria-label="დახურვა">${ic('x')}</button></div><div class="pvframe"><div class="pvtrack"><div class="pvs">${opt.video?`<video src="${esc(url)}" controls autoplay playsinline></video>`:`<img src="${esc(url)}" alt="">`}</div></div></div></div>`;document.documentElement.classList.add('pvopen')}
function popAct(id){const b=$(`.post[data-id="${id}"] .rwrap .act`);if(b){pop(b);burst(b)}}
async function setReaction(id,emoji){const s=STAT.get(id)||blankStat(id),old=s.my_reaction;
 if(old){s.reactions[old]=Math.max(0,(s.reactions[old]||1)-1);if(!s.reactions[old])delete s.reactions[old]}
 if(emoji){s.reactions[emoji]=(s.reactions[emoji]||0)+1}s.my_reaction=emoji;STAT.set(id,s);rerenderPost(id);if(emoji)popAct(id);
 try{if(emoji)await q(sb.from('reactions').upsert({post_id:id,user_id:ME.id,emoji},{onConflict:'post_id,user_id'}));else await q(sb.from('reactions').delete().eq('post_id',id).eq('user_id',ME.id))}catch(e){toast(errMsg(e))}}
A.react=t=>{const id=pidOf(t),s=STAT.get(id);if(s&&s.my_reaction){setReaction(id,null);return}
 const w=t.parentElement,open=$('.picker',w);$$('.picker').forEach(x=>x.remove());if(open)return;
 w.insertAdjacentHTML('beforeend',`<div class="picker" role="menu">${EMOJI.map(x=>`<button data-a="pick" data-e="${x}" role="menuitem" aria-label="${x==='🍷'?'ყანწი':x}">${rg(x)}</button>`).join('')}</div>`)};
A.pick=t=>setReaction(pidOf(t),t.dataset.e);
A.ecopost=t=>{const p=POSTS.get(pidOf(t));if(p){p._eco=true;rerenderPost(p.id)}};
A.dbl=t=>{const now=Date.now();if(now-(t._l||0)<330){t._l=0;const id=pidOf(t),b=$('.burst',t);if(b){b.classList.remove('go');void b.offsetWidth;b.classList.add('go')}const s=STAT.get(id);if(!s||s.my_reaction!=='❤️')setTimeout(()=>setReaction(id,'❤️'),500)}else t._l=now};
const gval=x=>x==='5+'?6:+x;
function refreshGrade(id){const p=POSTS.get(id);if(!p)return;const s=STAT.get(id)||blankStat(id),h=gradeHTML(p,s);$$(`.post[data-id="${id}"] .grade,[data-pv="${id}"] .grade`).forEach(el=>{el.outerHTML=h});$$(`.pgt[data-pid="${id}"] .pgg`).forEach(el=>{el.outerHTML=gridGrade(p,s)})}
A.grade=async t=>{const id=pidOf(t),g=t.dataset.g,p=POSTS.get(id),s=STAT.get(id)||blankStat(id);if(p?.author===ME.id){toast('საკუთარ ფოტოს ვერ შეაფასებ');return}
 const prev=s.my_grade;if(prev===g)return;const old={my_grade:s.my_grade,grade_n:s.grade_n,grade_avg:s.grade_avg},n=s.grade_n||0,avg=+s.grade_avg||0;
 s.my_grade=g;s.grade_n=prev?n:n+1;s.grade_avg=Math.round((avg*n-(prev?gval(prev):0)+gval(g))/s.grade_n*10)/10;STAT.set(id,s);refreshGrade(id);
 const nb=$(`.post[data-id="${id}"] .grade button[data-g="${g}"],[data-pv="${id}"] .grade button[data-g="${g}"]`);if(nb)pop(nb);
 try{const paid=await rpc('grade_photo',{p_post:id,p_grade:g});
  toast(prev?'შეფასება შეიცვალა':(g==='5+'?'„5+“ გაიგზავნა':'შეფასება გაიგზავნა')+(paid>0?` · ავტორს +${paid} მონეტა`:''))}
 catch(e){Object.assign(s,old);STAT.set(id,s);refreshGrade(id);toast(errMsg(e))}};
A.vote=async t=>{const id=pidOf(t),i=+t.dataset.i,s=STAT.get(id)||blankStat(id);if(s.my_vote!=null&&s.my_vote!==i){s.votes[s.my_vote]=Math.max(0,(s.votes[s.my_vote]||1)-1)}if(s.my_vote!==i)s.votes[i]=(s.votes[i]||0)+1;s.my_vote=i;STAT.set(id,s);rerenderPost(id);
 try{await q(sb.from('poll_votes').upsert({post_id:id,user_id:ME.id,opt:i},{onConflict:'post_id,user_id'}))}catch(e){toast(errMsg(e))}};
A.save=async t=>{const id=pidOf(t),s=STAT.get(id)||blankStat(id);s.saved=!s.saved;STAT.set(id,s);rerenderPost(id);if(!s.saved)toast('შენახულიდან ამოიშალა');
 try{if(s.saved){await q(sb.from('saves').insert({user_id:ME.id,post_id:id}));savedBanner(id)}else await q(sb.from('saves').delete().eq('user_id',ME.id).eq('post_id',id))}catch(e){toast(errMsg(e))}};
async function shareLink(url,title){try{if(navigator.share){await navigator.share({title:title||'სუფრა',url});return}}catch(e){if(e.name==='AbortError')return}try{await navigator.clipboard.writeText(url);toast('ბმული დაკოპირდა')}catch(e){toast(url)}}
/* sharing: repost, quote, story, message, link */
A.share=t=>{const id=pidOf(t),p=POSTS.get(id);if(!p)return;const r=RS.get(id)||{n:0,mine:null},own=p.author===ME.id,canRp=!p.group_id&&!own&&!p.hidden&&!p.draft;
 sheet(head('გაზიარება')+`<div class="shgrid">${canRp?`<button data-a="${r.mine?'unrepost':'repost'}" data-pid="${id}"${r.mine?` data-rid="${r.mine}"`:''}><span class="shi${r.mine?' on':''}">${ic('repost')}</span>${r.mine?'გაუქმება':'რეპოსტი'}</button><button data-a="quote" data-pid="${id}"><span class="shi">${ic('edit')}</span>ციტირებით</button>`:''}
  ${p.group_id?'':`<button data-a="storypost" data-pid="${id}"><span class="shi">${ic('story')}</span>ისტორიაში</button>`}<button data-a="sendpost" data-pid="${id}"><span class="shi">${ic('send')}</span>მესიჯით</button><button data-a="copylink" data-pid="${id}"><span class="shi">${ic('share')}</span>ბმული</button></div>
  ${r.n?`<p class="note" style="padding:0 16px 16px">${r.n} ${r.n===1?'ადამიანმა':'ადამიანმა'} გააზიარა</p>`:own?'<p class="note" style="padding:0 16px 16px">საკუთარ პოსტს რეპოსტს ვერ გაუკეთებ, მაგრამ ისტორიაში ან მესიჯით გაზიარება შეგიძლია.</p>':''}`,'short')};
const rpErr=e=>/duplicate|unique/i.test(e.message||'')?'უკვე გაზიარებული გაქვს':/not_found/.test(e.message||'')?'პოსტი აღარ არის ხელმისაწვდომი':/not_allowed/.test(e.message||'')?'ჯგუფის პოსტის გაზიარება არ შეიძლება':/blocked/.test(e.message||'')?'ვერ გააზიარებ':errMsg(e);
A.repost=async t=>{const id=pidOf(t);closeSheet();try{const row=await q(sb.from('posts').insert({author:ME.id,body:'',repost_of:id}).select('id').single());const r=RS.get(id)||{post_id:id,n:0,mine:null};r.n++;r.mine=row.id;RS.set(id,r);rerenderPost(id);toast('გაზიარდა შენს მეგობრებთან')}catch(e){toast(rpErr(e))}};
A.unrepost=async t=>{const id=pidOf(t),rid=+t.dataset.rid||RS.get(id)?.mine;closeSheet();if(!rid)return;try{await q(sb.from('posts').delete().eq('id',rid).eq('author',ME.id));const r=RS.get(id);if(r){r.n=Math.max(0,r.n-1);r.mine=null}POSTS.delete(rid);$$(`.rpw[data-rid="${rid}"]`).forEach(e=>e.remove());rerenderPost(id);toast('რეპოსტი გაუქმდა')}catch(e){toast(errMsg(e))}};
A.quote=t=>{const id=pidOf(t),o=POSTS.get(id);if(!o)return;
 sheet(`<div class="ph-head cmphead"><button class="ibtn" data-a="close" aria-label="დახურვა">${ic('x')}</button><h2>ციტირება</h2><span class="sp"></span><button class="btn" id="q_pub" disabled>გაზიარება</button></div>
  <div class="ph-body cmp"><div class="cmpwho">${av('me',46)}<div class="grow"><b>${esc(ME.name)}</b><span class="sub">${ic('globe')}ყველა ნახავს</span></div></div><textarea id="q_t" class="ctext big" rows="3" maxlength="2000" placeholder="დაამატე შენი აზრი…" aria-label="შენი ტექსტი"></textarea>${quoteHTML(o,1)}</div>`,'cmpanel');
 const ta=$('#q_t'),b=$('#q_pub');mentionable(ta);ta.oninput=()=>{b.disabled=!ta.value.trim()};setTimeout(()=>ta.focus(),250);
 b.onclick=async()=>{const body=ta.value.trim();if(!body)return;b.disabled=true;b.textContent='ქვეყნდება…';
  try{const row=await q(sb.from('posts').insert({author:ME.id,body,repost_of:id}).select(POSTSEL).single());await hydrate([row]);const r=RS.get(id)||{post_id:id,n:0,mine:null};r.n++;RS.set(id,r);closeSheet();toast('გაზიარდა');
   const feed=$('#feed');if(feed)feed.insertAdjacentHTML('afterbegin',postHTML(row));rerenderPost(id)}catch(e){toast(rpErr(e));b.disabled=false;b.textContent='გაზიარება'}}};
A.copylink=t=>{const id=pidOf(t);closeSheet();shareLink(location.origin+'/#post-'+id)};
A.sendpost=async t=>{const id=pidOf(t);if(!POSTS.get(id))return;let convs=[];try{convs=await myChats()}catch(e){}await loadProfiles(convs.flatMap(c=>c.members||[]));
 sheet(head('მესიჯით გაგზავნა')+`<div class="ph-body" style="padding:0"><div class="list">${convs.slice(0,40).map(c=>{const o=!c.is_group&&c.members?.[0];return `<button class="row" data-a="sendpostto" data-pid="${id}" data-c="${c.conv_id}">${o?av(o,42):`<span class="av gav" style="--s:42px;--h:${(c.conv_id*47)%360}">${ic('users')}</span>`}<span class="grow"><b>${esc(c.is_group?(c.title||'ჯგუფი'):pname(o))}</b></span><span class="spst">${ic('send')}</span></button>`}).join('')||empty('საუბრები ჯერ არ გაქვს','მიწერე მეგობარს და აქ გამოჩნდება.')}</div></div>`)};
A.sendpostto=async t=>{const id=pidOf(t),p=POSTS.get(id),cid=+t.dataset.c;if(!p||t.dataset.sent)return;t.disabled=true;const u=p.page?{name:p.page.name}:(p.ap||prof(p.author)),m=pmedia(p)[0];
 try{await q(sb.from('messages').insert({conv_id:cid,sender:ME.id,body:location.origin+'/#post-'+id,media:{post:{id,by:String(u.name||'').slice(0,60),t:String(p.body||'').slice(0,140),img:m?(m.type==='video'?mPoster(m):mSm(m))||'':''}}}));t.dataset.sent=1;const x=$('.spst',t);if(x)x.innerHTML='<span class="ptag">გაიგზავნა</span>'}catch(e){toast(errMsg(e))}t.disabled=false};
/* a story picture made from the post: the photo on a card with the author's name */
async function postCardImage(p){const W=1080,H=1920,c=document.createElement('canvas');c.width=W;c.height=H;const x=c.getContext('2d');
 const u=p.page?{name:p.page.name,hue:p.page.hue,avatar_url:p.page.avatar_url}:(p.ap||prof(p.author)),hue=(((u.hue??200)%360)+360)%360;
 const font=getComputedStyle(document.body).fontFamily||'sans-serif';try{await document.fonts?.ready}catch(e){}
 const g=x.createLinearGradient(0,0,W,H);g.addColorStop(0,`hsl(${hue} 42% 24%)`);g.addColorStop(1,`hsl(${(hue+40)%360} 48% 9%)`);x.fillStyle=g;x.fillRect(0,0,W,H);
 const ld=src=>new Promise(r=>{if(!safeU(src)){r(null);return}const im=new Image();im.crossOrigin='anonymous';im.onload=()=>r(im);im.onerror=()=>r(null);im.src=src;setTimeout(()=>r(null),9000)});
 const ms=pmedia(p),m=ms.find(z=>z.type==='image')||ms.find(z=>z.type==='video'&&mPoster(z));
 const[img,avi]=await Promise.all([m?ld(m.type==='video'?mPoster(m):mMd(m)):null,ld(u.avatar_url)]);
 const rr=(X,Y,w,h,r)=>{x.beginPath();x.moveTo(X+r,Y);x.arcTo(X+w,Y,X+w,Y+h,r);x.arcTo(X+w,Y+h,X,Y+h,r);x.arcTo(X,Y+h,X,Y,r);x.arcTo(X,Y,X+w,Y,r);x.closePath()};
 const wrap=(t,maxW,maxL)=>{const words=String(t).replace(/\s+/g,' ').trim().split(' '),out=[];let line='',i=0;for(;i<words.length;i++){const tt=line?line+' '+words[i]:words[i];if(x.measureText(tt).width>maxW&&line){out.push(line);line=words[i];if(out.length===maxL)break}else line=tt}
  if(out.length<maxL&&line){out.push(line);i=words.length}if(i<words.length){let l=out[maxL-1]||'';while(l&&x.measureText(l+'…').width>maxW)l=l.slice(0,-1);out[maxL-1]=l+'…'}return out};
 const cw=920,cx=(W-cw)/2;let ih=0;if(img)ih=Math.max(520,Math.min(1040,Math.round((cw-48)*img.height/img.width)));
 x.font=`500 42px ${font}`;const lines=p.body?wrap(p.body,cw-96,img?3:10):[];
 const ch=150+(img?ih+20:0)+(lines.length?lines.length*60+40:20),cy=Math.max(120,Math.round((H-ch)/2-30));
 x.save();x.shadowColor='rgba(0,0,0,.45)';x.shadowBlur=60;x.shadowOffsetY=24;rr(cx,cy,cw,ch,44);x.fillStyle='#fff';x.fill();x.restore();
 const ay=cy+40;x.save();x.beginPath();x.arc(cx+86,ay+38,38,0,Math.PI*2);x.closePath();x.clip();
 if(avi){const s2=Math.max(76/avi.width,76/avi.height);x.drawImage(avi,cx+86-avi.width*s2/2,ay+38-avi.height*s2/2,avi.width*s2,avi.height*s2)}else{x.fillStyle=`hsl(${hue} 55% 45%)`;x.fillRect(cx+48,ay,76,76);x.fillStyle='#fff';x.font=`700 36px ${font}`;x.textAlign='center';x.textBaseline='middle';x.fillText(String(u.name||'?').slice(0,1),cx+86,ay+40)}x.restore();
 x.textAlign='left';x.textBaseline='alphabetic';x.fillStyle='#1d1420';x.font=`700 38px ${font}`;x.fillText(String(u.name||'').slice(0,26),cx+144,ay+34);x.fillStyle='#7a6d78';x.font=`400 30px ${font}`;x.fillText(p.page?'არხი სუფრაზე':'პოსტი სუფრაზე',cx+144,ay+74);
 let yy=cy+150;if(img){x.save();rr(cx+24,yy,cw-48,ih,28);x.clip();const sc=Math.max((cw-48)/img.width,ih/img.height),dw=img.width*sc,dh=img.height*sc;x.drawImage(img,cx+24+((cw-48)-dw)/2,yy+(ih-dh)/2,dw,dh);x.restore();yy+=ih+20}
 if(lines.length){x.fillStyle='#2a2030';x.font=`500 42px ${font}`;lines.forEach((l,i)=>x.fillText(l,cx+48,yy+48+i*60))}
 x.fillStyle='rgba(255,255,255,.82)';x.font=`600 34px ${font}`;x.textAlign='center';x.fillText('სუფრა',W/2,H-140);
 return new Promise((res,rej)=>{try{c.toBlob(b=>b?res(b):rej(new Error('სურათი ვერ შეიქმნა')),'image/jpeg',.9)}catch(e){rej(e)}})}
A.storypost=async t=>{const id=pidOf(t),p=POSTS.get(id);if(!p)return;closeSheet();toast('ისტორია მზადდება…');
 try{const b=await postCardImage(p);const url=await uploadBlob(b,'jpg');await q(sb.from('stories').insert({author:ME.id,media_url:url,media_type:'image',audience:'all',post_id:id}));toast('დაემატა შენს ისტორიაში');if($('#stories'))loadStories()}catch(e){toast(errMsg(e))}};
/* editing a published post: text, removing photos, the place */
A.editpost=t=>{const id=pidOf(t),p=POSTS.get(id);if(!p||p.author!==ME.id)return;const E={media:pmedia(p).slice(),place:p.pl||null};
 sheet(`<div class="ph-head cmphead"><button class="ibtn" data-a="close" aria-label="დახურვა">${ic('x')}</button><h2>პოსტის რედაქტირება</h2><span class="sp"></span><button class="btn" id="e_save">შენახვა</button></div>
  <div class="ph-body cmp"><textarea id="e_t" class="ctext big" rows="5" maxlength="2000" aria-label="ტექსტი" placeholder="ტექსტი">${esc(p.body||'')}</textarea>
  <div id="e_m" class="cattach"></div>${p.repost_of?quoteHTML(POSTS.get(p.repost_of),1):'<div id="e_pl" class="eplace"></div>'}
  ${p.poll?'<p class="note">გამოკითხვა არ იცვლება, რომ მიცემული ხმები არ დაიკარგოს.</p>':''}<p class="note">რედაქტირებულ პოსტთან გამოჩნდება „რედაქტირებული“.</p></div>`,'cmpanel');
 const drawM=()=>{const el=$('#e_m');if(!el)return;el.innerHTML=E.media.map((m,i)=>`<div class="catt">${m.type==='video'?(mPoster(m)?`<img src="${esc(mPoster(m))}" alt="">`:`<video src="${esc(m.url)}" muted playsinline preload="metadata"></video>`):`<img src="${esc(mSm(m))}" alt="">`}<button type="button" data-erm="${i}" aria-label="${m.type==='video'?'ვიდეოს':'ფოტოს'} მოშორება">${ic('x')}</button></div>`).join('');$$('[data-erm]',el).forEach(b=>b.onclick=()=>{E.media.splice(+b.dataset.erm,1);drawM()})};
 const drawPl=()=>{const el=$('#e_pl');if(!el)return;el.innerHTML=(E.place?`<span class="cplchip">📍 ${esc(E.place.name)}<button type="button" id="e_plx" aria-label="ადგილის მოშორება">${ic('x')}</button></span>`:'')+`<button type="button" class="btn sm ghost" id="e_plc">${ic('pin')}${E.place?'ადგილის შეცვლა':'ადგილის მითითება'}</button>`;
  const x=$('#e_plx');if(x)x.onclick=()=>{E.place=null;drawPl()};$('#e_plc').onclick=async()=>{const pl=await pickPlace();if(pl){E.place=pl;drawPl()}}};
 drawM();drawPl();mentionable($('#e_t'));
 $('#e_save').onclick=async()=>{const b=$('#e_save'),body=$('#e_t').value.trim();
  if(p.repost_of&&!body){toast('ციტირებას ტექსტი სჭირდება');return}if(!p.repost_of&&!body&&!E.media.length&&!p.poll&&!E.place){toast('პოსტი ცარიელი ვერ დარჩება');return}
  const upd={body};if(!p.repost_of){upd.media=E.media;upd.place_id=E.place?E.place.id:null}b.disabled=true;
  try{const row=await q(sb.from('posts').update(upd).eq('id',id).eq('author',ME.id).select(POSTSEL).single());await hydrate([row]);closeSheet();rerenderPost(id);toast('შესწორდა')}catch(e){toast(errMsg(e));b.disabled=false}}};
A.lightbox=t=>openPV(pidOf(t),+t.dataset.i||0);
A.pmore=t=>{const id=pidOf(t),p=POSTS.get(id);if(!p)return;const mine=p.author===ME.id;
 sheet(head('პოსტი')+`<div class="reasons">${String(p.body||'').trim()?`<button data-a="speakpost" data-pid="${id}">${ic('mic')} მოსმენა</button>`:''}${mine?`${p.repost_of&&!p.body?'':`<button data-a="editpost" data-pid="${id}">რედაქტირება</button>`}<button data-a="delpost" data-pid="${id}">პოსტის წაშლა</button>${p.page_id?`<button data-a="adnew" data-pid="${id}">რეკლამის გაშვება</button>`:''}`:`<button data-a="hidepost" data-pid="${id}">დამალვა ჩემს ფიდში</button><button data-a="report" data-type="post" data-id="${id}" data-u="${p.author}">საჩივარი პოსტზე</button><button class="warnbtn" data-a="block" data-u="${p.author}">ავტორის დაბლოკვა</button>`}
 ${isStaff()?`<button data-a="modhide" data-type="post" data-id="${id}" data-h="${p.hidden?0:1}">${p.hidden?'მოდერაცია: გამოჩენა':'მოდერაცია: დამალვა ყველასთვის'}</button>${!mine?`<button class="warnbtn" data-a="ban" data-u="${p.author}">ავტორის შეზღუდვა</button>`:''}`:''}</div>`,'short')};
/* read a post aloud with the device's voice (Georgian needs a Georgian voice on the device) */
let SPEAKING=null;
function speak(text){const s=window.speechSynthesis;if(!s||!window.SpeechSynthesisUtterance){toast('ამ ბრაუზერს ხმამაღლა წაკითხვა არ შეუძლია');return}
 if(s.speaking||s.pending){s.cancel();if(SPEAKING===text){SPEAKING=null;toast('შეჩერდა');return}}
 const t=String(text||'').replace(/https?:\/\/\S+/g,'').trim().slice(0,4000);if(!t)return;
 const ka=/[\u10A0-\u10FF]/.test(t),cy=/[\u0400-\u04FF]/.test(t),lang=ka?'ka':cy?'ru':'en',voices=s.getVoices(),v=voices.find(x=>String(x.lang||'').toLowerCase().startsWith(lang));
 if(ka&&!v){toast('შენს მოწყობილობაზე ქართული ხმა არ არის. დააყენე ტელეფონის პარამეტრებში: „ტექსტის ხმად გადაყვანა“ → ქართული');return}
 const u=new window.SpeechSynthesisUtterance(t);u.lang=v?.lang||({ka:'ka-GE',ru:'ru-RU',en:'en-US'})[lang];if(v)u.voice=v;u.rate=.95;u.onend=()=>{if(SPEAKING===text)SPEAKING=null};SPEAKING=text;s.speak(u);toast('იკითხება. შესაჩერებლად ისევ „მოსმენა“')}
try{window.speechSynthesis?.getVoices();window.speechSynthesis?.addEventListener?.('voiceschanged',()=>{})}catch(e){}
A.speakpost=t=>{const p=POSTS.get(pidOf(t));closeSheet();if(p)speak(p.body)};
A.hidepost=t=>{LOCALHIDE[pidOf(t)]=1;store.set('hidden',LOCALHIDE);closeSheet();$$(`.post[data-id="${pidOf(t)}"]`).forEach(e=>e.remove());toast('პოსტი დაიმალა')};
A.delpost=t=>{const id=pidOf(t);confirmSheet('პოსტის წაშლა','წაშლილ პოსტს ვეღარ აღადგენ.','წაშლა',async()=>{await q(sb.from('posts').delete().eq('id',id));if(PV&&PV.id===id)closePV();$$(`.rpw[data-orig="${id}"],.rpw[data-rid="${id}"]`).forEach(e=>e.remove());$$(`.post[data-id="${id}"]`).forEach(e=>e.remove());POSTS.delete(id);toast('პოსტი წაიშალა')},true)};
A.modhide=async t=>{try{await rpc('admin_hide',{p_type:t.dataset.type,p_id:+t.dataset.id,p_hidden:t.dataset.h==='1'});closeSheet();toast(t.dataset.h==='1'?'დაიმალა ყველასთვის':'ისევ ჩანს');if(t.dataset.type==='post'){const p=POSTS.get(+t.dataset.id);if(p){p.hidden=t.dataset.h==='1';rerenderPost(p.id)}}}catch(e){toast(errMsg(e))}};
A.ban=t=>confirmSheet('მომხმარებლის შეზღუდვა','შეზღუდული მომხმარებელი ვეღარ დაწერს პოსტებს, კომენტარებს და შეტყობინებებს.','შეზღუდვა',async()=>{await rpc('admin_ban',{p_user:t.dataset.u,p_banned:true});toast('შეიზღუდა')},true);
A.tag=t=>openPage('tag',t.dataset.t);
A.uname=async t=>{try{const d=await q(sb.from('profiles').select(PCOLS).eq('username',t.dataset.u).maybeSingle());if(!d){toast('მომხმარებელი ვერ მოიძებნა');return}PC.set(d.id,d);openPage('user',d.id)}catch(e){toast(errMsg(e))}};
A.user=t=>openPage('user',t.dataset.u);

/* comments: one level of replies, likes */
const CSEL='id,body,media,created_at,author,parent_id,likes,profiles!comments_author_fkey(id,name,username,avatar_url,hue,verified)';
let CMT=null;
function commentRow(c,pa,hide){const u=c.profiles||prof(c.author);if(c.profiles)PC.set(u.id,Object.assign(PC.get(u.id)||{},u));const can=c.author===ME.id||pa===ME.id||isStaff(),liked=!!CMT?.liked.has(c.id),rep=!!c.parent_id;
 return `<div class="trow cmt${rep?' rep':''}" data-cid="${c.id}"${rep?` data-parent="${c.parent_id}"`:''}${hide?' hidden':''}><button data-a="user" data-u="${u.id}" aria-label="${esc(u.name)}">${av(u,rep?28:34)}</button><div class="grow"><div class="cbub${cmMedia(c)?' hasm':''}${c.media&&c.media.sticker&&!cmBody(c)?' stkonly':''}"><b>${esc(u.name)}${vb(u)}</b>${cmBody(c)}${cmMedia(c)}</div>
  <div class="cmeta"><span>${ago(c.created_at)}</span><button data-a="cmlike" data-cid="${c.id}" class="${liked?'on':''}" aria-pressed="${liked}">${liked?'მოგწონს':'მოწონება'}</button><button data-a="creply" data-cid="${c.id}">პასუხი</button>${can?`<button data-a="delcomment" data-cid="${c.id}">წაშლა</button>`:''}${c.likes?`<span class="clk" aria-label="${c.likes} მოწონება">${ic('heart','currentColor')}${c.likes}</span>`:''}</div></div></div>`}
/* a comment can be a sticker or a photo; the placeholder text the server keeps for it is not shown */
const cmStk=k=>(STICKERS.find(x=>x[0]===k)||[])[1];
function cmBody(c){const m=c.media||{},b=String(c.body||'');if(m.sticker&&(b==='✨'||b===cmStk(m.sticker)))return '';if(m.url&&b==='📷')return '';return tx(b)}
function cmMedia(c){const m=c.media;if(!m)return '';if(m.sticker)return `<span class="cstk">${stickerSVG(m.sticker)}</span>`;
 if(m.url)return `<button class="cimg" data-a="cimgv" data-src="${esc(m.url)}" style="--ar:${m.w>0&&m.h>0?m.w+'/'+m.h:'4/3'}" aria-label="ფოტოს გადიდება"><img src="${esc(m.sm||m.url)}" alt="" loading="lazy"></button>`;return ''}
A.cimgv=t=>openImage(t.dataset.src,{top:true});
function threadHTML(c,kids,pa){const hid=kids.length>3?kids.length-2:0;
 return `<div class="cth" data-th="${c.id}">${commentRow(c,pa)}<div class="creps">${hid?`<button class="cmore" data-a="cmore" data-th="${c.id}">${ic('reply')}კიდევ ${hid} პასუხის ნახვა</button>`:''}${kids.map((r,i)=>commentRow(r,pa,i<hid)).join('')}</div></div>`}
function setCReply(c){if(!CMT)return;CMT.reply=c?{id:c.parent_id||c.id,name:pname(c.author)}:null;const bar=$('#crb'),i=$('#cin');if(!bar||!i)return;
 if(!c){bar.hidden=true;bar.innerHTML='';i.placeholder='დაწერე კომენტარი…';return}
 bar.hidden=false;bar.innerHTML=`${ic('reply')}<div class="grow"><b>პასუხი: ${esc(String(pname(c.author)).split(' ')[0])}</b><span>${esc(String(c.body).slice(0,80))}</span></div><button type="button" class="ibtn sm" id="crbx" aria-label="პასუხის გაუქმება">${ic('x')}</button>`;$('#crbx').onclick=()=>setCReply(null);
 const un=prof(c.author).username;if(c.parent_id&&un&&c.author!==ME.id&&!i.value.includes('@'+un))i.value=`@${un} `+i.value;i.placeholder=`უპასუხე ${String(pname(c.author)).split(' ')[0]}-ს…`;i.focus()}
async function openComments(id){const p=POSTS.get(id),pa=p?.author;CMT={post:id,rows:new Map(),liked:new Set(),reply:null};const st=CMT;
 navMark('comments',()=>openComments(id));sheet(head('კომენტარები')+`<div class="ph-body" id="cb">${skel(2)}</div><form class="ph-foot chatfoot cfoot" id="cf"><div class="replybar" id="crb" hidden></div><div class="chrow"><button type="button" class="ibtn" id="c_stk" aria-label="სტიკერი">${ic('smile')}</button><button type="button" class="ibtn" id="c_img" aria-label="ფოტო">${ic('image')}</button><input class="field" id="cin" maxlength="1000" placeholder="დაწერე კომენტარი…" aria-label="კომენტარი" autocomplete="off"><button class="btn" aria-label="გაგზავნა">${ic('send')}</button></div></form>`,'',()=>{if(CMT===st)CMT=null});mentionable($('#cin'));
 try{const rows=await q(sb.from('comments').select(CSEL).eq('post_id',id).order('created_at').limit(400));rows.forEach(c=>st.rows.set(c.id,c));
  if(rows.length){try{(await q(sb.from('comment_likes').select('comment_id').eq('user_id',ME.id).in('comment_id',rows.map(c=>c.id).slice(0,400)))).forEach(x=>st.liked.add(x.comment_id))}catch(e){}}
  const kids=new Map();rows.forEach(c=>{if(c.parent_id&&st.rows.has(c.parent_id)){if(!kids.has(c.parent_id))kids.set(c.parent_id,[]);kids.get(c.parent_id).push(c)}});
  const top=rows.filter(c=>!c.parent_id||!st.rows.has(c.parent_id));if(CMT!==st)return;
  $('#cb').innerHTML=top.map(c=>threadHTML(c,kids.get(c.id)||[],pa)).join('')||'<p class="muted" id="cempty">ჯერ არავის დაუწერია. იყავი პირველი.</p>';$('#cb').scrollTop=S.openComments===false?0:1e6}catch(e){$('#cb').innerHTML=`<p class="muted">${errMsg(e)}</p>`}
 const send=async(v,media)=>{const par=st.reply;setCReply(null);
  try{const c=await q(sb.from('comments').insert({post_id:id,author:ME.id,body:v,parent_id:par?par.id:null,media:media||null}).select(CSEL).single());if(CMT!==st)return true;st.rows.set(c.id,c);$('#cempty')?.remove();const cb=$('#cb');
   const th=c.parent_id&&$(`.cth[data-th="${c.parent_id}"] .creps`,cb);if(th){th.insertAdjacentHTML('beforeend',commentRow(c,pa));th.lastElementChild.scrollIntoView({block:'nearest'})}else{cb.insertAdjacentHTML('beforeend',threadHTML(c,[],pa));cb.scrollTop=1e6}
   const s=STAT.get(id)||blankStat(id);s.comments++;STAT.set(id,s);rerenderPost(id);return true}catch(x){toast(errMsg(x));return false}};
 $('#cf').onsubmit=async e=>{e.preventDefault();const i=$('#cin'),v=i.value.trim();if(!v)return;i.value='';if(!await send(v))i.value=v};
 $('#c_stk').onclick=async()=>{const k=await pickSticker();if(!k||CMT!==st)return;send(cmStk(k)||'✨',{sticker:k})};
 $('#c_img').onclick=async()=>{const b=await pickImage({max:ECO()?1080:1600});if(!b||CMT!==st)return;const i=$('#cin'),v=i?i.value.trim():'';
  try{toast('იტვირთება…');const m=await uploadMedia(b,'image');if(i)i.value='';if(!await send(v||'📷',{url:m.url,sm:m.sm||undefined,w:m.w,h:m.h})&&i)i.value=v}catch(e){toast(errMsg(e))}}}
A.comments=t=>openComments(pidOf(t));
A.creply=t=>{const c=CMT?.rows.get(+t.dataset.cid);if(c)setCReply(c)};
A.cmore=t=>{const th=t.closest('.cth');if(!th)return;$$('.trow[hidden]',th).forEach(r=>r.hidden=false);t.remove()};
A.cmlike=async t=>{const st=CMT,c=st?.rows.get(+t.dataset.cid);if(!c)return;const on=!st.liked.has(c.id);if(on)st.liked.add(c.id);else st.liked.delete(c.id);c.likes=Math.max(0,(c.likes||0)+(on?1:-1));
 const row=t.closest('.trow');if(row){const h=row.hidden;row.outerHTML=commentRow(c,POSTS.get(st.post)?.author,h);if(on){const b=$(`.trow[data-cid="${c.id}"] [data-a="cmlike"]`);if(b)pop(b)}}
 try{if(on)await q(sb.from('comment_likes').insert({comment_id:c.id,user_id:ME.id}));else await q(sb.from('comment_likes').delete().eq('comment_id',c.id).eq('user_id',ME.id))}catch(e){if(!/duplicate/i.test(e.message||''))toast(errMsg(e))}};
A.delcomment=t=>{const cid=+t.dataset.cid,st=CMT;confirmSheet('კომენტარის წაშლა','წაიშლება კომენტარი და მისი პასუხებიც.','წაშლა',async()=>{await q(sb.from('comments').delete().eq('id',cid));if(!st)return;const n=1+[...st.rows.values()].filter(c=>c.parent_id===cid).length;st.rows.delete(cid);
 const th=$(`.cth[data-th="${cid}"]`);if(th)th.remove();else $(`.trow[data-cid="${cid}"]`)?.remove();const s=STAT.get(st.post);if(s){s.comments=Math.max(0,s.comments-n);rerenderPost(st.post)}},true,true)};

/* @mentions: typing "@" suggests friends and people by username */
function mentionable(el){if(!el||el._ment)return;el._ment=1;let box=null,tm,tok=0,list=[],sel=0;
 const close=()=>{box?.remove();box=null;list=[]};
 const pick=u=>{const v=el.value,pos=el.selectionStart??v.length,before=v.slice(0,pos).replace(/@([A-Za-z0-9_.]{0,24})$/,'@'+u.username+' ');el.value=before+v.slice(pos);try{el.setSelectionRange(before.length,before.length)}catch(e){}el.focus();close();el.dispatchEvent(new Event('input'))};
 const show=l=>{list=l.slice(0,6);sel=0;if(!list.length){close();return}if(!box){box=document.createElement('div');box.className='mbox';box.setAttribute('role','listbox');document.body.appendChild(box)}
  box.innerHTML=list.map((u,i)=>`<button type="button" role="option" data-i="${i}" aria-selected="${!i}">${av(u,30)}<span><b>${esc(u.name)}${vb(u)}</b><small>@${esc(u.username)}</small></span></button>`).join('');
  $$('button',box).forEach(b=>{b.onmousedown=e=>e.preventDefault();b.onclick=()=>pick(list[+b.dataset.i])});
  const r=el.getBoundingClientRect(),h=Math.min(260,list.length*48+8),below=innerHeight-r.bottom;box.style.left=Math.max(8,Math.min(r.left,innerWidth-Math.min(320,innerWidth-16)-8))+'px';box.style.width=Math.min(320,innerWidth-16)+'px';
  if(below>h+8){box.style.top=(r.bottom+4)+'px';box.style.bottom='auto'}else{box.style.top='auto';box.style.bottom=(innerHeight-r.top+4)+'px'}};
 el.addEventListener('input',()=>{const m=el.value.slice(0,el.selectionStart??el.value.length).match(/(^|[^A-Za-z0-9_.@])@([A-Za-z0-9_.]{0,24})$/);if(!m){close();return}const pre=m[2].toLowerCase(),my=++tok;
  const local=[...PC.values()].filter(u=>u&&u.username&&u.id!==ME.id&&!BLOCKED.has(u.id)&&(String(u.username).toLowerCase().startsWith(pre)||String(u.name||'').toLowerCase().split(' ').some(w=>w.startsWith(pre)))).sort((a,b)=>(FRIENDS.has(b.id)?1:0)-(FRIENDS.has(a.id)?1:0));
  show(local);clearTimeout(tm);if(pre.length>=2)tm=setTimeout(async()=>{try{const rows=await q(sb.from('profiles').select(PCOLS).ilike('username',pre.replace(/[%_\\]/g,'\\$&')+'%').eq('onboarded',true).neq('id',ME.id).limit(6));if(my!==tok||!el.isConnected)return;
   rows.forEach(p=>PC.set(p.id,Object.assign(PC.get(p.id)||{},p)));const all=[...local];rows.forEach(r=>{if(r.username&&!all.some(x=>x.id===r.id)&&!BLOCKED.has(r.id))all.push(r)});show(all)}catch(e){}},250)});
 el.addEventListener('keydown',e=>{if(!box||!list.length)return;if(e.key==='Escape'){e.stopPropagation();close();return}
  if(e.key==='ArrowDown'||e.key==='ArrowUp'){e.preventDefault();sel=(sel+(e.key==='ArrowDown'?1:list.length-1))%list.length;$$('button',box).forEach((b,i)=>b.setAttribute('aria-selected',String(i===sel)));return}
  if(e.key==='Enter'||e.key==='Tab'){e.preventDefault();pick(list[sel])}});
 el.addEventListener('blur',()=>setTimeout(close,180))}

/* composer */
let CMP=null;
async function myPages(){try{return await q(sb.from('pages').select('id,name,hue,kind,avatar_url').eq('owner',ME.id))}catch(e){return []}}
async function compose(opt={}){CMP={files:[],poll:null,page:opt.page_id||null,group:opt.group_id||null,clip:!!opt.clip,place:opt.place||null};const pages=opt.group_id?[]:await myPages();
 const title=opt.clip?'ახალი კლიპი':opt.group_id?'პოსტი ჯგუფში':'ახალი პოსტი';
 sheet(`<div class="ph-head cmphead"><button class="ibtn" data-a="close" aria-label="დახურვა">${ic('x')}</button><h2>${title}</h2><span class="sp"></span><button class="btn" id="c_pub" disabled>გამოქვეყნება</button></div>
  <div class="ph-body cmp"><div class="cmpwho">${av('me',46)}<div class="grow"><b id="c_asn">${esc(ME.name)}</b><span class="sub">${ic(opt.group_id?'users':'globe')}${opt.group_id?'ჯგუფის წევრები ნახავენ':'ყველა ნახავს'}</span></div></div>
  ${pages.length?`<div class="chipsbar" style="padding:0" role="group" aria-label="ვისი სახელით"><button data-as="" aria-pressed="${!CMP.page}">${esc(ME.name)}</button>${pages.map(p=>`<button data-as="${p.id}" aria-pressed="${CMP.page===p.id}">${esc(p.name)}</button>`).join('')}</div>`:''}
  <textarea id="ct" class="ctext big" rows="5" maxlength="2000" placeholder="${opt.clip?'კლიპის აღწერა, #ჰეშთეგები':`რა ხდება, ${firstName()}?`}" aria-label="ტექსტი">${esc(opt.text||'')}</textarea>
  <div class="tlchip" id="tlc" hidden><span>ლათინური ასოებით წერ? <b>ერთი შეხებით გადაიყვანე.</b></span><button type="button" class="btn sm ghost" id="tlb">ქართულ ასოებზე</button></div>
  <div id="cplace"></div><div class="cattach" id="cat"></div><div id="clink"></div><div id="cpoll"></div>
  <div class="csched" id="csch" hidden><label class="fld">გამოქვეყნების დრო<input type="datetime-local" id="c_when"></label><div class="row2" style="justify-content:flex-start"><button type="button" class="btn sm ghost" id="c_draft">${ic('edit')}დრაფტად შენახვა</button><button type="button" class="btn sm" id="c_plan">${ic('clock')}დაგეგმვა</button></div><p class="note">დრაფტები და დაგეგმილი პოსტები ჩანს პროფილზე → „დრაფტები“.</p></div>
  <span class="cnt" id="cc">#ჰეშთეგი · @მომხმარებელი · 0/2000</span></div>
  <div class="ph-foot cmptools" role="group" aria-label="დაამატე პოსტს"><button class="ctool t-img" id="c_img"><span>${ic('image')}</span>ფოტო</button><button class="ctool t-vid" id="c_vid"><span>${ic('clips')}</span>ვიდეო</button>${opt.clip?'':`<button class="ctool t-poll" id="c_poll"><span>${ic('poll')}</span>გამოკითხვა</button>`}<button class="ctool t-pl" id="c_pl"><span>${ic('pin')}</span>ადგილი</button><button class="ctool t-sch" id="c_sch"><span>${ic('clock')}</span>მოგვიანებით</button></div>`,'cmpanel');
 const updPub=()=>{const b=$('#c_pub');if(b&&CMP)b.disabled=!($('#ct').value.trim()||CMP.files.length||CMP.poll||CMP.place)};CMP.upd=updPub;
 const ta=$('#ct');mentionable(ta);ta.oninput=()=>{$('#cc').textContent=`#ჰეშთეგი · @მომხმარებელი · ${ta.value.length}/2000`;updPub();$('#tlc').hidden=!(ta.value.trim().length>5&&detect(ta.value)==='ka-lat');clearTimeout(CMP.lt);CMP.lt=setTimeout(checkLink,700)};
 const drawLink=()=>{const el=$('#clink');if(!el)return;el.innerHTML=CMP.link&&!CMP.files.length?`<div class="clinkw">${linkCard(CMP.link)}<button type="button" class="ibtn sm" id="c_lrm" aria-label="ბარათის მოშორება">${ic('x')}</button></div>`:'';const x=$('#c_lrm');if(x)x.onclick=()=>{CMP.linkOff=CMP.linkUrl;CMP.link=null;drawLink()}};
 const checkLink=async()=>{const m=(ta.value.match(/https?:\/\/[^\s<]+/)||[])[0];if(!m){CMP.link=null;CMP.linkUrl=null;drawLink();return}if(m===CMP.linkUrl||m===CMP.linkOff)return;CMP.linkUrl=m;const d=await unfurl(m);if(CMP&&CMP.linkUrl===m){CMP.link=d;drawLink()}};
 const pad=n=>String(n).padStart(2,'0'),dl=d=>`${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
 $('#c_when').value=dl(new Date(Date.now()+36e5));$('#c_when').min=dl(new Date(Date.now()+6e4));
 $('#c_sch').onclick=()=>{const b=$('#csch');b.hidden=!b.hidden;$('#c_sch').setAttribute('aria-pressed',String(!b.hidden))};
 const drawPlace=()=>{const el=$('#cplace');if(!el)return;el.innerHTML=CMP.place?`<span class="cplchip">📍 ${esc(CMP.place.name)}<button type="button" id="c_plx" aria-label="მოშორება">${ic('x')}</button></span>`:'';const x=$('#c_plx');if(x)x.onclick=()=>{CMP.place=null;drawPlace()};updPub()};drawPlace();
 $('#c_pl').onclick=async()=>{const pl=await pickPlace();if(pl&&CMP){CMP.place=pl;drawPlace()}};
 $('#c_draft').onclick=()=>publish('draft');$('#c_plan').onclick=()=>publish('plan');
 $('#tlb').onclick=()=>{ta.value=translit(ta.value);ta.oninput()};
 $$('[data-as]',$('#sheet')).forEach(b=>b.onclick=()=>{CMP.page=b.dataset.as?+b.dataset.as:null;$$('[data-as]',$('#sheet')).forEach(z=>z.setAttribute('aria-pressed',String(z===b)));$('#c_asn').textContent=b.textContent});
 const drawAtt=()=>{$('#cat').innerHTML=CMP.files.map((f,i)=>`<div class="catt">${f.type==='video'?`<video src="${f.url}" muted playsinline></video>`:`<img src="${f.url}" alt="">`}<button type="button" data-rm="${i}" aria-label="წაშლა">${ic('x')}</button></div>`).join('');$$('[data-rm]',$('#cat')).forEach(b=>b.onclick=()=>{CMP.files.splice(+b.dataset.rm,1);drawAtt()});updPub()};
 const addImgs=async()=>{if(CMP.clip){toast('კლიპისთვის აირჩიე ვიდეო');return}const fs=await pickFile('image/*',{multiple:true});if(!fs.length)return;
  for(const f of fs.slice(0,10-CMP.files.length)){let b=f;if(fs.length===1&&f.type!=='image/gif'){b=await editImage(f);if(!b)break}else if(f.type!=='image/gif'){b=await shrink(f)}if(b)CMP.files.push({blob:b,type:'image',url:URL.createObjectURL(b)})}
  if($('#cat'))drawAtt()};
 const addVid=async()=>{const v=await pickVideo();if(!v)return;CMP.files=CMP.files.filter(f=>f.type!=='video');CMP.files.push({blob:v,type:'video',url:URL.createObjectURL(v)});drawAtt()};
 const pollUI=()=>{updPub();if(!CMP.poll){$('#cpoll').innerHTML='';return}$('#cpoll').innerHTML=`<div class="cpoll"><input class="field sq" id="pq" maxlength="140" placeholder="კითხვა" value="${esc(CMP.poll.q)}">${CMP.poll.opts.map((o,i)=>`<div class="prow"><input class="field sq" data-po="${i}" maxlength="60" placeholder="პასუხი ${i+1}" value="${esc(o)}">${i>1?`<button type="button" class="ibtn sm" data-pr="${i}" aria-label="წაშლა">${ic('x')}</button>`:''}</div>`).join('')}<div style="display:flex;gap:8px">${CMP.poll.opts.length<6?'<button type="button" class="btn sm ghost" id="padd">პასუხის დამატება</button>':''}<button type="button" class="btn sm ghost" id="prm">გამოკითხვის წაშლა</button></div></div>`;
  $('#pq').oninput=e=>CMP.poll.q=e.target.value;$$('[data-po]').forEach(i=>i.oninput=e=>CMP.poll.opts[+i.dataset.po]=e.target.value);$$('[data-pr]').forEach(b=>b.onclick=()=>{CMP.poll.opts.splice(+b.dataset.pr,1);pollUI()});
  const pa=$('#padd');if(pa)pa.onclick=()=>{CMP.poll.opts.push('');pollUI()};$('#prm').onclick=()=>{CMP.poll=null;pollUI()}};
 function rebind(){$('#c_img').onclick=addImgs;$('#c_vid').onclick=addVid;const pb=$('#c_poll');if(pb)pb.onclick=()=>{CMP.poll=CMP.poll||{q:'',opts:['','']};pollUI()};$('#c_pub').onclick=()=>publish('now')}
 rebind();if(opt.clip)setTimeout(addVid,200);if(opt.text){ta.oninput();setTimeout(()=>{ta.focus();ta.setSelectionRange(ta.value.length,ta.value.length)},250)}
 async function publish(mode='now'){const body=$('#ct').value.trim();let poll=null,when=null;
  if(mode==='plan'){const v=$('#c_when').value;when=v?new Date(v):null;if(!when||isNaN(when)||when.getTime()<Date.now()+3e4){toast('აირჩიე მომავალი დრო');return}}
  if(CMP.poll){const opts=CMP.poll.opts.map(s=>s.trim()).filter(Boolean);if(!CMP.poll.q.trim()||opts.length<2){toast('გამოკითხვას სჭირდება კითხვა და მინიმუმ 2 პასუხი');return}poll={q:CMP.poll.q.trim(),opts}}
  if(!body&&!CMP.files.length&&!poll&&!CMP.place){toast('დაწერე რამე ან დაამატე ფოტო');return}
  if(mode==='now'&&CMP.clip&&!CMP.files.some(f=>f.type==='video')){toast('კლიპისთვის საჭიროა ვიდეო');return}
  const btn=$('#c_pub');btn.disabled=true;const media=[];
  try{for(let i=0;i<CMP.files.length;i++){btn.textContent=`იტვირთება ${i+1}/${CMP.files.length}…`;const f=CMP.files[i];media.push(await uploadMedia(f.blob,f.type))}
   btn.textContent='ქვეყნდება…';
   const rowIn={author:ME.id,body,media,poll,page_id:CMP.page,group_id:CMP.group,link:media.length?null:CMP.link||null,place_id:CMP.place?CMP.place.id:null,is_clip:CMP.clip||(media.length===1&&media[0].type==='video'&&/#კლიპი|#clip/i.test(body))};
   if(mode!=='now'){await q(sb.from('posts').insert(Object.assign(rowIn,{draft:mode==='draft',publish_at:when?when.toISOString():null})));closeSheet();toast(mode==='draft'?'დრაფტი შენახულია':'დაიგეგმა: '+fdate(when));return}
   const row=await q(sb.from('posts').insert(rowIn).select(POSTSEL).single());
   await hydrate([row]);closeSheet();toast('გამოქვეყნდა');
   const feed=$('#feed');if(feed&&!CMP.group){feed.insertAdjacentHTML('afterbegin',postHTML(row));anim($('.post',feed),[{opacity:0,transform:'translateY(-12px) scale(.98)'},{opacity:1,transform:'none'}],{duration:500,easing:SPRING})}else rp()}
  catch(e){toast(errMsg(e));btn.disabled=false;btn.textContent='გამოქვეყნება'}}}
async function shrink(file,max=1600){try{const im=await loadImg(URL.createObjectURL(file));const sc=Math.min(1,max/Math.max(im.width,im.height));const c=document.createElement('canvas');c.width=Math.round(im.width*sc);c.height=Math.round(im.height*sc);c.getContext('2d').drawImage(im,0,0,c.width,c.height);return await new Promise(r=>c.toBlob(r,'image/jpeg',.86))}catch(e){return file}}
A.compose=()=>compose();
