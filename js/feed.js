/* posts: loading, rendering, reactions, polls, comments, composer */
const POSTSEL='id,author,body,media,poll,tags,group_id,page_id,is_clip,hidden,created_at,link,draft,publish_at,ap:profiles!posts_author_fkey(id,name,username,avatar_url,hue,verified,is_business),page:pages!posts_page_id_fkey(id,name,hue,avatar_url,verified,kind),grp:groups!posts_group_id_fkey(id,name),pl:places!posts_place_id_fkey(id,name,kind,city)';
const POSTS=new Map(),STAT=new Map();
const EMOJI=['👍','❤️','😂','😮','😢','😡','🍷'];
const blankStat=id=>({post_id:id,reactions:{},my_reaction:null,comments:0,grade_avg:null,grade_n:0,my_grade:null,votes:{},my_vote:null,saved:false});
async function hydrate(rows){rows=rows||[];rows.forEach(p=>{if(p.ap)PC.set(p.ap.id,Object.assign(PC.get(p.ap.id)||{},p.ap));POSTS.set(p.id,p)});
 if(rows.length){try{const st=await rpc('feed_stats',{p_ids:rows.map(p=>p.id)});st.forEach(s=>STAT.set(s.post_id,s))}catch(e){}}
 return rows}
async function fetchPosts(build){return hydrate(await q(build(sb.from('posts').select(POSTSEL).eq('draft',false).lte('created_at',new Date(Date.now()+3e5).toISOString()))))}
const LOCALHIDE=store.get('hidden',{});
const rTotal=s=>Object.values(s.reactions||{}).reduce((a,b)=>a+b,0);
const rTop=s=>Object.entries(s.reactions||{}).sort((a,b)=>b[1]-a[1]).slice(0,3).map(e=>rg(e[0])).join('');
function mediaBlock(p){const m=Array.isArray(p.media)?p.media:[];if(!m.length)return '';
 if(ECO()&&!p._eco)return `<button class="ecoimg" data-a="ecopost" data-pid="${p.id}">${ic(m.some(x=>x.type==='video')?'clips':'image')}<span>${m.length>1?m.length+' ფაილი':m[0].type==='video'?'ვიდეო':'ფოტო'} · დააჭირე ჩასატვირთად</span></button>`;
 if(m.length===1){const x=m[0];return x.type==='video'?`<div class="ph vid">${mediaHTML(x)}</div>`:`<div class="ph" data-a="dbl" data-pid="${p.id}">${mediaHTML(x)}<span class="burst">${ic('heart','currentColor')}</span></div>`}
 const show=m.slice(0,4);return `<div class="mg n${show.length}">${show.map((x,i)=>`<button class="mgi" data-a="lightbox" data-pid="${p.id}" data-i="${i}" aria-label="ფოტო ${i+1}">${x.type==='video'?`<video src="${esc(x.url)}" muted playsinline preload="metadata"></video><span class="playi">${ic('clips')}</span>`:`<img src="${esc(x.url)}" alt="" loading="lazy">`}${i===3&&m.length>4?`<span class="more">+${m.length-4}</span>`:''}</button>`).join('')}</div>`}
function pollBlock(p,s){if(!p.poll||!Array.isArray(p.poll.opts))return '';const tot=Object.values(s.votes||{}).reduce((a,b)=>a+b,0),voted=s.my_vote!=null;
 return `<div class="poll" role="group" aria-label="გამოკითხვა"><b>${esc(p.poll.q)}</b>${p.poll.opts.map((o,i)=>{const n=s.votes?.[i]||0,pc=tot?Math.round(n/tot*100):0;return `<button class="popt${s.my_vote===i?' mine':''}" data-a="vote" data-pid="${p.id}" data-i="${i}"${voted?` style="--pc:${pc}%"`:''}><span>${esc(o)}</span>${voted?`<em>${pc}%</em>`:''}</button>`}).join('')}<span class="note">${tot} ხმა${voted?'':' · აირჩიე პასუხი'}</span></div>`}
function postHTML(p){const s=STAT.get(p.id)||blankStat(p.id),u=p.ap||prof(p.author),pg=p.page,m=s.my_reaction,hasImg=(p.media||[]).some(x=>x.type==='image');
 const who=pg?`<button class="pname" data-a="pagev" data-id="${pg.id}"><b>${esc(pg.name)}${pg.verified?vb({verified:1}):''}</b></button><span class="ptag">${pg.kind==='business'?'ბიზნესი':'არხი'}</span>`:`<button class="pname" data-a="user" data-u="${u.id}"><b>${esc(u.name)}${vb(u)}</b></button>`;
 return `<article class="post${p.hidden?' is-hidden':''}" data-id="${p.id}"><div class="lane">${pg?`<button data-a="pagev" data-id="${pg.id}" aria-label="${esc(pg.name)}">${avAny({n:pg.name,h:pg.hue},40).replace('class="av"','class="av sq"')}</button>`:`<button data-a="user" data-u="${u.id}" aria-label="${esc(u.name)}">${av(u)}</button>`}${s.comments?'<span class="thr"></span>':''}</div><div class="pbody">
 <div class="meta">${who}${p.grp?`<button class="ptag" data-a="group" data-id="${p.grp.id}">${esc(p.grp.name)}</button>`:''}${p.pl?`<button class="ptag plc" data-a="page" data-p="place" data-arg="${p.pl.id}">📍 ${esc(p.pl.name)}</button>`:''}<span>${ago(p.created_at)}</span>${p.hidden?'<span class="ptag warn">დამალულია</span>':''}${p.ad?'<span class="ptag ad">რეკლამა</span>':''}</div>
 ${tx(p.body)}${mediaBlock(p)}${p.link&&!(p.media||[]).length?linkCard(p.link):''}${pollBlock(p,s)}
 ${hasImg?`<div class="grade" role="group" aria-label="ფოტოს შეფასება"><span>შეფასება</span>${['1','2','3','4','5','5+'].map(x=>`<button data-a="grade" data-g="${x}" class="${x==='5+'?'plus':''}${s.my_grade===x?' on':''}">${x}</button>`).join('')}${s.grade_n?`<em>საშ. ${s.grade_avg} · ${s.grade_n}</em>`:''}</div>`:''}
 <div class="acts"><div class="rwrap"><button class="act${m?' on':''}" data-a="react" aria-label="რეაქცია">${m?`<span class="em">${rg(m)}</span>`:ic('heart')}<span>${rTotal(s)||''}</span></button></div>
 <button class="act" data-a="comments" aria-label="კომენტარები">${ic('comment')}<span>${s.comments||''}</span></button>
 <button class="act" data-a="share" aria-label="გაზიარება">${ic('send')}</button>
 <button class="act${s.saved?' on':''}" data-a="save" aria-label="${s.saved?'შენახულია':'შენახვა'}">${ic('bookmark',s.saved?'currentColor':'')}</button>
 <span class="rsum" aria-hidden="true">${rTop(s)}</span><button class="act" data-a="pmore" aria-label="მეტი მოქმედება">${ic('more')}</button></div></div></article>`}
const pidOf=t=>+(t.dataset.pid||t.closest('.post')?.dataset.id);
function rerenderPost(id){$$(`.post[data-id="${id}"]`).forEach(el=>{const p=POSTS.get(id);if(p)el.outerHTML=postHTML(p)})}
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
A.grade=async t=>{const id=pidOf(t),g=t.dataset.g,s=STAT.get(id)||blankStat(id);s.my_grade=g;STAT.set(id,s);$$('button',t.parentElement).forEach(b=>b.classList.toggle('on',b===t));pop(t);
 try{await q(sb.from('post_grades').upsert({post_id:id,user_id:ME.id,grade:g},{onConflict:'post_id,user_id'}));toast(g==='5+'?'„5+“ გაეგზავნა ავტორს':'შეფასება შენახულია')}catch(e){toast(errMsg(e))}};
A.vote=async t=>{const id=pidOf(t),i=+t.dataset.i,s=STAT.get(id)||blankStat(id);if(s.my_vote!=null&&s.my_vote!==i){s.votes[s.my_vote]=Math.max(0,(s.votes[s.my_vote]||1)-1)}if(s.my_vote!==i)s.votes[i]=(s.votes[i]||0)+1;s.my_vote=i;STAT.set(id,s);rerenderPost(id);
 try{await q(sb.from('poll_votes').upsert({post_id:id,user_id:ME.id,opt:i},{onConflict:'post_id,user_id'}))}catch(e){toast(errMsg(e))}};
A.save=async t=>{const id=pidOf(t),s=STAT.get(id)||blankStat(id);s.saved=!s.saved;STAT.set(id,s);rerenderPost(id);toast(s.saved?'შენახულია. ნახე პროფილში → შენახული':'შენახულიდან ამოიშალა');
 try{if(s.saved)await q(sb.from('saves').insert({user_id:ME.id,post_id:id}));else await q(sb.from('saves').delete().eq('user_id',ME.id).eq('post_id',id))}catch(e){toast(errMsg(e))}};
async function shareLink(url,title){try{if(navigator.share){await navigator.share({title:title||'სუფრა',url});return}}catch(e){if(e.name==='AbortError')return}try{await navigator.clipboard.writeText(url);toast('ბმული დაკოპირდა')}catch(e){toast(url)}}
A.share=t=>shareLink(location.origin+'/#post-'+pidOf(t));
A.lightbox=t=>{const p=POSTS.get(pidOf(t)),i=+t.dataset.i||0;sheet(head(`${(p.media||[]).length} ფაილი`)+`<div class="ph-body lb">${(p.media||[]).map(m=>mediaHTML(m,'lbm')).join('')}</div>`);setTimeout(()=>{const el=$$('.lbm',$('#sheet'))[i];if(el)el.scrollIntoView({block:'start'})},60)};
A.pmore=t=>{const id=pidOf(t),p=POSTS.get(id);if(!p)return;const mine=p.author===ME.id;
 sheet(head('პოსტი')+`<div class="reasons">${mine?`<button data-a="delpost" data-pid="${id}">პოსტის წაშლა</button>${p.page_id?`<button data-a="adnew" data-pid="${id}">რეკლამის გაშვება</button>`:''}`:`<button data-a="hidepost" data-pid="${id}">დამალვა ჩემს ფიდში</button><button data-a="report" data-type="post" data-id="${id}" data-u="${p.author}">საჩივარი პოსტზე</button><button class="warnbtn" data-a="block" data-u="${p.author}">ავტორის დაბლოკვა</button>`}
 ${isStaff()?`<button data-a="modhide" data-type="post" data-id="${id}" data-h="${p.hidden?0:1}">${p.hidden?'მოდერაცია: გამოჩენა':'მოდერაცია: დამალვა ყველასთვის'}</button>${!mine?`<button class="warnbtn" data-a="ban" data-u="${p.author}">ავტორის შეზღუდვა</button>`:''}`:''}</div>`,'short')};
A.hidepost=t=>{LOCALHIDE[pidOf(t)]=1;store.set('hidden',LOCALHIDE);closeSheet();$$(`.post[data-id="${pidOf(t)}"]`).forEach(e=>e.remove());toast('პოსტი დაიმალა')};
A.delpost=t=>{const id=pidOf(t);confirmSheet('პოსტის წაშლა','წაშლილ პოსტს ვეღარ აღადგენ.','წაშლა',async()=>{await q(sb.from('posts').delete().eq('id',id));$$(`.post[data-id="${id}"]`).forEach(e=>e.remove());toast('პოსტი წაიშალა')},true)};
A.modhide=async t=>{try{await rpc('admin_hide',{p_type:t.dataset.type,p_id:+t.dataset.id,p_hidden:t.dataset.h==='1'});closeSheet();toast(t.dataset.h==='1'?'დაიმალა ყველასთვის':'ისევ ჩანს');if(t.dataset.type==='post'){const p=POSTS.get(+t.dataset.id);if(p){p.hidden=t.dataset.h==='1';rerenderPost(p.id)}}}catch(e){toast(errMsg(e))}};
A.ban=t=>confirmSheet('მომხმარებლის შეზღუდვა','შეზღუდული მომხმარებელი ვეღარ დაწერს პოსტებს, კომენტარებს და შეტყობინებებს.','შეზღუდვა',async()=>{await rpc('admin_ban',{p_user:t.dataset.u,p_banned:true});toast('შეიზღუდა')},true);
A.tag=t=>openPage('tag',t.dataset.t);
A.uname=async t=>{try{const d=await q(sb.from('profiles').select(PCOLS).eq('username',t.dataset.u).maybeSingle());if(!d){toast('მომხმარებელი ვერ მოიძებნა');return}PC.set(d.id,d);openPage('user',d.id)}catch(e){toast(errMsg(e))}};
A.user=t=>openPage('user',t.dataset.u);

/* comments */
function commentRow(c,postAuthor){const u=c.profiles||prof(c.author);if(c.profiles)PC.set(u.id,Object.assign(PC.get(u.id)||{},u));const can=c.author===ME.id||postAuthor===ME.id||isStaff();
 return `<div class="trow" data-cid="${c.id}"><button data-a="user" data-u="${u.id}" aria-label="${esc(u.name)}">${av(u,34)}</button><div class="grow"><b>${esc(u.name)}${vb(u)} <span class="muted" style="font-weight:400;font-size:12px">${ago(c.created_at)}</span></b>${tx(c.body)}</div>${can?`<button class="ibtn sm" data-a="delcomment" data-cid="${c.id}" aria-label="კომენტარის წაშლა">${ic('x')}</button>`:''}</div>`}
async function openComments(id){const p=POSTS.get(id);
 sheet(head('კომენტარები')+`<div class="ph-body" id="cb">${skel(2)}</div><form class="ph-foot" id="cf"><input class="field" id="cin" maxlength="1000" placeholder="დაწერე კომენტარი…" aria-label="კომენტარი" autocomplete="off"><button class="btn">გაგზავნა</button></form>`);
 try{const rows=await q(sb.from('comments').select('id,body,created_at,author,profiles!comments_author_fkey(id,name,username,avatar_url,hue,verified)').eq('post_id',id).order('created_at').limit(300));
  $('#cb').innerHTML=rows.map(c=>commentRow(c,p?.author)).join('')||'<p class="muted">ჯერ არავის დაუწერია. იყავი პირველი.</p>';$('#cb').scrollTop=1e6}catch(e){$('#cb').innerHTML=`<p class="muted">${errMsg(e)}</p>`}
 $('#cf').onsubmit=async e=>{e.preventDefault();const i=$('#cin'),v=i.value.trim();if(!v)return;i.value='';
  try{const c=await q(sb.from('comments').insert({post_id:id,author:ME.id,body:v}).select('id,body,created_at,author').single());const cb=$('#cb');if(cb.querySelector('.muted'))cb.innerHTML='';cb.insertAdjacentHTML('beforeend',commentRow(c,p?.author));cb.scrollTop=1e6;
   const s=STAT.get(id)||blankStat(id);s.comments++;STAT.set(id,s);rerenderPost(id)}catch(x){toast(errMsg(x));i.value=v}}}
A.comments=t=>openComments(pidOf(t));
A.delcomment=async t=>{const cid=+t.dataset.cid;try{await q(sb.from('comments').delete().eq('id',cid));t.closest('.trow').remove()}catch(e){toast(errMsg(e))}};

/* composer */
let CMP=null;
async function myPages(){try{return await q(sb.from('pages').select('id,name,hue,kind').eq('owner',ME.id))}catch(e){return []}}
async function compose(opt={}){CMP={files:[],poll:null,page:opt.page_id||null,group:opt.group_id||null,clip:!!opt.clip,place:opt.place||null};const pages=opt.group_id?[]:await myPages();
 sheet(head(opt.clip?'ახალი კლიპი':opt.group_id?'პოსტი ჯგუფში':'ახალი პოსტი')+`<div class="ph-body">
  ${pages.length?`<div class="chipsbar" style="padding:0" role="group" aria-label="ვისი სახელით"><button data-as="" aria-pressed="${!CMP.page}">${esc(ME.name)}</button>${pages.map(p=>`<button data-as="${p.id}" aria-pressed="${CMP.page===p.id}">${esc(p.name)}</button>`).join('')}</div>`:''}
  <textarea id="ct" class="ctext" rows="4" maxlength="2000" placeholder="${opt.clip?'კლიპის აღწერა, #ჰეშთეგები':'რა ხდება? გამოიყენე #ჰეშთეგები და @მომხმარებელი'}" aria-label="ტექსტი"></textarea>
  <div class="tlchip" id="tlc" hidden><span>ლათინური ასოებით წერ? <b>ერთი შეხებით გადაიყვანე.</b></span><button type="button" class="btn sm ghost" id="tlb">ქართულ ასოებზე</button></div>
  <div id="cplace"></div><div class="cattach" id="cat"></div><div id="clink"></div><div id="cpoll"></div>
  <div class="csched" id="csch" hidden><label class="fld">გამოქვეყნების დრო<input type="datetime-local" id="c_when"></label><div class="row2" style="justify-content:flex-start"><button type="button" class="btn sm ghost" id="c_draft">${ic('edit')}დრაფტად შენახვა</button><button type="button" class="btn sm" id="c_plan">${ic('clock')}დაგეგმვა</button></div><p class="note">დრაფტები და დაგეგმილი პოსტები ჩანს პროფილზე → „დრაფტები“.</p></div>
  <span class="cnt" id="cc">0/2000</span></div>
  <div class="ph-foot cbar"><button class="ibtn" id="c_img" aria-label="ფოტოს დამატება">${ic('image')}</button><button class="ibtn" id="c_vid" aria-label="ვიდეოს დამატება">${ic('clips')}</button>${opt.clip?'':`<button class="ibtn" id="c_poll" aria-label="გამოკითხვა">${ic('poll')}</button>`}<button class="ibtn" id="c_pl" aria-label="ადგილის მონიშვნა">${ic('pin')}</button><button class="ibtn" id="c_sch" aria-label="დრაფტი ან დაგეგმვა">${ic('clock')}</button><span class="sp"></span><button class="btn" id="c_pub">გამოქვეყნება</button></div>`);
 const ta=$('#ct');ta.oninput=()=>{$('#cc').textContent=ta.value.length+'/2000';$('#tlc').hidden=!(ta.value.trim().length>5&&detect(ta.value)==='ka-lat');clearTimeout(CMP.lt);CMP.lt=setTimeout(checkLink,700)};
 const drawLink=()=>{const el=$('#clink');if(!el)return;el.innerHTML=CMP.link&&!CMP.files.length?`<div class="clinkw">${linkCard(CMP.link)}<button type="button" class="ibtn sm" id="c_lrm" aria-label="ბარათის მოშორება">${ic('x')}</button></div>`:'';const x=$('#c_lrm');if(x)x.onclick=()=>{CMP.linkOff=CMP.linkUrl;CMP.link=null;drawLink()}};
 const checkLink=async()=>{const m=(ta.value.match(/https?:\/\/[^\s<]+/)||[])[0];if(!m){CMP.link=null;CMP.linkUrl=null;drawLink();return}if(m===CMP.linkUrl||m===CMP.linkOff)return;CMP.linkUrl=m;const d=await unfurl(m);if(CMP&&CMP.linkUrl===m){CMP.link=d;drawLink()}};
 const pad=n=>String(n).padStart(2,'0'),dl=d=>`${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
 $('#c_when').value=dl(new Date(Date.now()+36e5));$('#c_when').min=dl(new Date(Date.now()+6e4));
 $('#c_sch').onclick=()=>{const b=$('#csch');b.hidden=!b.hidden;$('#c_sch').setAttribute('aria-pressed',String(!b.hidden))};
 const drawPlace=()=>{const el=$('#cplace');if(!el)return;el.innerHTML=CMP.place?`<span class="cplchip">📍 ${esc(CMP.place.name)}<button type="button" id="c_plx" aria-label="მოშორება">${ic('x')}</button></span>`:'';const x=$('#c_plx');if(x)x.onclick=()=>{CMP.place=null;drawPlace()}};drawPlace();
 $('#c_pl').onclick=async()=>{const pl=await pickPlace();if(pl&&CMP){CMP.place=pl;drawPlace()}};
 $('#c_draft').onclick=()=>publish('draft');$('#c_plan').onclick=()=>publish('plan');
 $('#tlb').onclick=()=>{ta.value=translit(ta.value);ta.oninput()};
 $$('[data-as]',$('#sheet')).forEach(b=>b.onclick=()=>{CMP.page=b.dataset.as?+b.dataset.as:null;$$('[data-as]',$('#sheet')).forEach(z=>z.setAttribute('aria-pressed',String(z===b)))});
 const drawAtt=()=>{$('#cat').innerHTML=CMP.files.map((f,i)=>`<div class="catt">${f.type==='video'?`<video src="${f.url}" muted playsinline></video>`:`<img src="${f.url}" alt="">`}<button type="button" data-rm="${i}" aria-label="წაშლა">${ic('x')}</button></div>`).join('');$$('[data-rm]',$('#cat')).forEach(b=>b.onclick=()=>{CMP.files.splice(+b.dataset.rm,1);drawAtt()})};
 const addImgs=async()=>{if(CMP.clip){toast('კლიპისთვის აირჩიე ვიდეო');return}const fs=await pickFile('image/*',{multiple:true});if(!fs.length)return;
  for(const f of fs.slice(0,10-CMP.files.length)){let b=f;if(fs.length===1&&f.type!=='image/gif'){b=await editImage(f);if(!b)break}else if(f.type!=='image/gif'){b=await shrink(f)}if(b)CMP.files.push({blob:b,type:'image',url:URL.createObjectURL(b)})}
  if($('#cat'))drawAtt()};
 const addVid=async()=>{const v=await pickVideo();if(!v)return;CMP.files=CMP.files.filter(f=>f.type!=='video');CMP.files.push({blob:v,type:'video',url:URL.createObjectURL(v)});drawAtt()};
 const pollUI=()=>{if(!CMP.poll){$('#cpoll').innerHTML='';return}$('#cpoll').innerHTML=`<div class="cpoll"><input class="field sq" id="pq" maxlength="140" placeholder="კითხვა" value="${esc(CMP.poll.q)}">${CMP.poll.opts.map((o,i)=>`<div class="prow"><input class="field sq" data-po="${i}" maxlength="60" placeholder="პასუხი ${i+1}" value="${esc(o)}">${i>1?`<button type="button" class="ibtn sm" data-pr="${i}" aria-label="წაშლა">${ic('x')}</button>`:''}</div>`).join('')}<div style="display:flex;gap:8px">${CMP.poll.opts.length<6?'<button type="button" class="btn sm ghost" id="padd">პასუხის დამატება</button>':''}<button type="button" class="btn sm ghost" id="prm">გამოკითხვის წაშლა</button></div></div>`;
  $('#pq').oninput=e=>CMP.poll.q=e.target.value;$$('[data-po]').forEach(i=>i.oninput=e=>CMP.poll.opts[+i.dataset.po]=e.target.value);$$('[data-pr]').forEach(b=>b.onclick=()=>{CMP.poll.opts.splice(+b.dataset.pr,1);pollUI()});
  const pa=$('#padd');if(pa)pa.onclick=()=>{CMP.poll.opts.push('');pollUI()};$('#prm').onclick=()=>{CMP.poll=null;pollUI()}};
 function rebind(){$('#c_img').onclick=addImgs;$('#c_vid').onclick=addVid;const pb=$('#c_poll');if(pb)pb.onclick=()=>{CMP.poll=CMP.poll||{q:'',opts:['','']};pollUI()};$('#c_pub').onclick=()=>publish('now')}
 rebind();if(opt.clip)setTimeout(addVid,200);
 async function publish(mode='now'){const body=$('#ct').value.trim();let poll=null,when=null;
  if(mode==='plan'){const v=$('#c_when').value;when=v?new Date(v):null;if(!when||isNaN(when)||when.getTime()<Date.now()+3e4){toast('აირჩიე მომავალი დრო');return}}
  if(CMP.poll){const opts=CMP.poll.opts.map(s=>s.trim()).filter(Boolean);if(!CMP.poll.q.trim()||opts.length<2){toast('გამოკითხვას სჭირდება კითხვა და მინიმუმ 2 პასუხი');return}poll={q:CMP.poll.q.trim(),opts}}
  if(!body&&!CMP.files.length&&!poll&&!CMP.place){toast('დაწერე რამე ან დაამატე ფოტო');return}
  if(mode==='now'&&CMP.clip&&!CMP.files.some(f=>f.type==='video')){toast('კლიპისთვის საჭიროა ვიდეო');return}
  const btn=$('#c_pub');btn.disabled=true;const media=[];
  try{for(let i=0;i<CMP.files.length;i++){btn.textContent=`იტვირთება ${i+1}/${CMP.files.length}…`;const f=CMP.files[i];media.push({url:await uploadBlob(f.blob,f.type==='video'?extOf(f.blob):'jpg'),type:f.type})}
   btn.textContent='ქვეყნდება…';
   const rowIn={author:ME.id,body,media,poll,page_id:CMP.page,group_id:CMP.group,link:media.length?null:CMP.link||null,place_id:CMP.place?CMP.place.id:null,is_clip:CMP.clip||(media.length===1&&media[0].type==='video'&&/#კლიპი|#clip/i.test(body))};
   if(mode!=='now'){await q(sb.from('posts').insert(Object.assign(rowIn,{draft:mode==='draft',publish_at:when?when.toISOString():null})));closeSheet();toast(mode==='draft'?'დრაფტი შენახულია':'დაიგეგმა: '+fdate(when));return}
   const row=await q(sb.from('posts').insert(rowIn).select(POSTSEL).single());
   await hydrate([row]);closeSheet();toast('გამოქვეყნდა');
   const feed=$('#feed');if(feed&&!CMP.group){feed.insertAdjacentHTML('afterbegin',postHTML(row));anim($('.post',feed),[{opacity:0,transform:'translateY(-12px) scale(.98)'},{opacity:1,transform:'none'}],{duration:500,easing:SPRING})}else rp()}
  catch(e){toast(errMsg(e));btn.disabled=false;btn.textContent='გამოქვეყნება'}}}
async function shrink(file,max=1600){try{const im=await loadImg(URL.createObjectURL(file));const sc=Math.min(1,max/Math.max(im.width,im.height));const c=document.createElement('canvas');c.width=Math.round(im.width*sc);c.height=Math.round(im.height*sc);c.getContext('2d').drawImage(im,0,0,c.width,c.height);return await new Promise(r=>c.toBlob(r,'image/jpeg',.86))}catch(e){return file}}
A.compose=()=>compose();
