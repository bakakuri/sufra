/* story archive and highlights, QR codes, badges, feed topics, saved folders */

/* ---------- highlights: the best stories stay on the profile ---------- */
async function loadHighlights(uid,el=$('#hlrow')){if(!el)return;const mine=uid===ME.id;
 try{const rows=await q(sb.from('highlights').select('id,title,cover_url,owner').eq('owner',uid).order('pos').order('id').limit(30));if(!el.isConnected)return;
  if(!rows.length&&!mine){el.innerHTML='';return}
  el.innerHTML=`<div class="hlrow" role="list" aria-label="რჩეულები">${mine?`<button class="hlc add" data-a="page" data-p="storyarch" role="listitem"><span class="hlr">${ic('plus')}</span><span>ახალი</span></button>`:''}${rows.map(h=>`<button class="hlc" data-a="hlopen" data-id="${h.id}" data-t="${esc(h.title)}" data-u="${uid}" role="listitem"><span class="hlr">${h.cover_url?`<img src="${esc(h.cover_url)}" alt="" loading="lazy">`:ic('star')}</span><span>${esc(h.title)}</span></button>`).join('')}</div>`}
 catch(e){el.innerHTML=''}}
A.hlopen=async t=>{const id=+t.dataset.id;try{const items=await q(sb.from('highlight_items').select('id,story_id,url,media_type,created_at').eq('highlight_id',id).order('created_at'));
 if(!items.length){toast('ეს რჩეული ცარიელია');return}
 openStory(0,0,[{a:t.dataset.u,hl:true,hid:id,title:t.dataset.t,list:items.map(x=>({id:x.story_id||('h'+x.id),hid:x.id,media_url:x.url,media_type:x.media_type,created_at:x.created_at}))}])}catch(e){toast(errMsg(e))}};
A.hlrmitem=t=>{const id=+t.dataset.id;closeStory();confirmSheet('რჩეულიდან ამოღება','ისტორია არქივში დარჩება, მხოლოდ ამ რჩეულიდან ამოიღება.','ამოღება',async()=>{await q(sb.from('highlight_items').delete().eq('id',id));toast('ამოღებულია');if(S.page?.id==='user'||S.tab==='me')loadHighlights(ME.id)},true)};
/* from the story viewer or the archive: put a story into a highlight */
A.sthl=t=>{const id=+t.dataset.id;closeStory();hlPick(id)};
async function hlPick(storyId){let rows=[];try{rows=await q(sb.from('highlights').select('id,title,cover_url').eq('owner',ME.id).order('pos').order('id'))}catch(e){}
 sheet(head('რჩეულებში დამატება')+`<div class="ph-body"><div class="list">${rows.map(h=>`<button class="row" data-a="hladd" data-h="${h.id}" data-s="${storyId}"><span class="hlr sm">${h.cover_url?`<img src="${esc(h.cover_url)}" alt="">`:ic('star')}</span><span class="grow"><b>${esc(h.title)}</b></span>${ic('plus')}</button>`).join('')}</div>
  <form class="row2" id="hlnf"><input class="field" id="hlnt" maxlength="24" placeholder="ახალი რჩეული, მაგ. ზღვა, სუფრები"><button class="btn">${ic('plus')}შექმნა</button></form></div>`,'short');
 $('#hlnf').onsubmit=async e=>{e.preventDefault();const title=$('#hlnt').value.trim();if(!title){toast('დაარქვი სახელი');return}
  try{const h=await q(sb.from('highlights').insert({owner:ME.id,title,pos:rows.length}).select('id').single());await rpc('add_to_highlight',{p_highlight:h.id,p_story:storyId});closeSheet();toast(`დაემატა რჩეულში „${title}“`)}catch(x){toast(errMsg(x))}}}
A.hladd=async t=>{try{const n=await rpc('add_to_highlight',{p_highlight:+t.dataset.h,p_story:+t.dataset.s});closeSheet();toast(n?'დაემატა რჩეულში':'ეს ისტორია უკვე ამ რჩეულშია')}catch(e){toast(errMsg(e))}};
/* the archive: every story you ever posted, only you see it */
PG.storyarch={r(){view.innerHTML=pgHead('ისტორიების არქივი')+`<p class="hint" style="padding:12px 16px 0">აქ ინახება შენი ყველა ისტორია, 24 საათის შემდეგაც. მხოლოდ შენ ხედავ. საუკეთესოები დაამატე რჩეულებში და პროფილზე გამოჩნდება.</p><div id="hlmine"></div><div id="arb">${skel(2)}</div>`;loadArchive()}};
async function loadArchive(){try{const[st,hl]=await Promise.all([q(sb.from('stories').select('id,media_url,media_type,created_at,expires_at').eq('author',ME.id).order('created_at',{ascending:false}).limit(300)),q(sb.from('highlights').select('id,title,cover_url').eq('owner',ME.id).order('pos').order('id'))]);
  const hm=$('#hlmine');if(hm)hm.innerHTML=hl.length?`<h3 class="sec2">ჩემი რჩეულები</h3><div class="list">${hl.map(h=>`<div class="row"><span class="hlr sm">${h.cover_url?`<img src="${esc(h.cover_url)}" alt="">`:ic('star')}</span><span class="grow"><b>${esc(h.title)}</b></span><button class="btn sm ghost" data-a="hlrename" data-id="${h.id}" data-t="${esc(h.title)}">${ic('edit')}</button><button class="ibtn sm" data-a="hldel" data-id="${h.id}" aria-label="წაშლა">${ic('trash')}</button></div>`).join('')}</div>`:'';
  const el=$('#arb');if(!el)return;if(!st.length){el.innerHTML=empty('არქივი ცარიელია','გამოაქვეყნე ისტორია და აქ შეინახება.','<button class="btn" data-a="addstory">ისტორიის დამატება</button>');return}
  let last='';el.innerHTML=`<div class="argrid">${st.map(x=>{const d=new Date(x.created_at),mk=MONTHS[d.getMonth()]+' '+d.getFullYear(),hdr=mk!==last?`<h4 class="argh">${mk}</h4>`:'';last=mk;
   return hdr+`<button class="art" data-a="arst" data-id="${x.id}" data-src="${esc(x.media_url)}" data-v="${x.media_type==='video'?1:0}">${x.media_type==='video'?`<video src="${esc(x.media_url)}#t=0.3" muted playsinline preload="metadata"></video>`:`<img src="${esc(x.media_url)}" alt="" loading="lazy">`}<span class="ard">${d.getDate()}</span>${new Date(x.expires_at)>new Date()?'<i class="arlive">ახლა ჩანს</i>':''}</button>`}).join('')}</div>`}
 catch(e){const el=$('#arb');if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
A.arst=t=>{const id=+t.dataset.id,src=t.dataset.src,v=t.dataset.v==='1';sheet(head('ისტორია')+`<div class="reasons"><button data-a="arview" data-src="${esc(src)}" data-v="${v?1:0}">${ic('eye')}ნახვა</button><button data-a="arhl" data-id="${id}">${ic('star')}რჩეულებში დამატება</button><button data-a="arshare" data-id="${id}">${ic('repost')}ხელახლა გაზიარება ისტორიად</button></div>`,'short')};
A.arview=t=>{openImage(t.dataset.src,{top:true,video:t.dataset.v==='1'})};
A.arhl=t=>{closeSheet(true);hlPick(+t.dataset.id)};
A.arshare=async t=>{try{const s=await q(sb.from('stories').select('media_url,media_type').eq('id',+t.dataset.id).single());await q(sb.from('stories').insert({author:ME.id,media_url:s.media_url,media_type:s.media_type,audience:'all'}));closeSheet();toast('ისტორია ხელახლა გაზიარდა');loadArchive()}catch(e){toast(errMsg(e))}};
A.hlrename=t=>{const id=+t.dataset.id;sheet(head('რჩეულის სახელი')+`<form class="ph-body" id="hlrf"><input class="field" id="hlrn" maxlength="24" value="${esc(t.dataset.t)}"><button class="btn">შენახვა</button></form>`,'short');
 $('#hlrf').onsubmit=async e=>{e.preventDefault();const v=$('#hlrn').value.trim();if(!v)return;try{await q(sb.from('highlights').update({title:v}).eq('id',id));closeSheet();loadArchive()}catch(x){toast(errMsg(x))}}};
A.hldel=t=>confirmSheet('რჩეულის წაშლა','წაიშლება მხოლოდ რჩეული. ისტორიები არქივში დარჩება.','წაშლა',async()=>{await q(sb.from('highlights').delete().eq('id',+t.dataset.id));loadArchive()},true);

/* ---------- QR code: show yours, scan a friend's ---------- */
let QRLIB=null;
function qrLib(){return QRLIB||(QRLIB=new Promise((res,rej)=>{const s=document.createElement('script');s.src='https://cdn.jsdelivr.net/npm/qrcode-generator@1.4.4/qrcode.js';s.onload=()=>res(window.qrcode);s.onerror=()=>{QRLIB=null;rej(new Error('QR კოდი ვერ ჩაიტვირთა. შეამოწმე ინტერნეტი'))};document.head.appendChild(s)}))}
A.sharepro=t=>qrSheet(t.dataset.u||ME.id);
async function qrSheet(uid){const p=prof(uid),mine=uid===ME.id,url=location.origin+'/#user-'+uid;
 sheet(head(mine?'ჩემი QR კოდი':'QR კოდი')+`<div class="ph-body qrb"><div class="qrcard"><div class="qrimg" id="qri"><span class="spin"></span></div><div class="qrwho">${av(p,36)}<b>${esc(p.name||'')}</b></div></div>
  <p class="note" style="text-align:center">${mine?'მეგობარი ტელეფონის კამერით დაასკანერებს და პირდაპირ შენს პროფილზე მოხვდება. სუფრაზე სახელის ძებნა აღარ დაგჭირდებათ.':'დაასკანერე ან გაუზიარე სხვას.'}</p>
  <div class="row2"><button class="btn" data-a="qrshare" data-u="${uid}">${ic('share')}ბმულის გაზიარება</button><button class="btn ghost" data-a="qrscan">${ic('camera')}სკანირება</button></div></div>`,'short');
 try{const qrcode=await qrLib();const qr=qrcode(0,'M');qr.addData(url);qr.make();const el=$('#qri');if(el)el.innerHTML=qr.createSvgTag({cellSize:6,margin:2,scalable:true})}catch(e){const el=$('#qri');if(el)el.innerHTML=`<p class="note">${esc(errMsg(e))}</p>`}}
A.qrshare=t=>shareLink(location.origin+'/#user-'+t.dataset.u);
A.qrscan=async()=>{const BD=window.BarcodeDetector;
 if(!BD||!navigator.mediaDevices?.getUserMedia){sheet(head('QR-ის სკანირება')+`<div class="ph-body"><p>გახსენი ტელეფონის კამერა და მიუშვირე მეგობრის QR კოდს. კამერა ბმულს თავად იცნობს: დააჭირე და პროფილი სუფრაში გაიხსნება.</p></div>`,'short');return}
 let stream;try{stream=await navigator.mediaDevices.getUserMedia({video:{facingMode:'environment'},audio:false})}catch(e){toast('კამერაზე წვდომა არ არის');return}
 let alive=true;const det=new BD({formats:['qr_code']});
 layer(lhead('QR-ის სკანირება')+`<div class="ph-body qrscan"><div class="qrcam"><video id="qrv" playsinline muted autoplay></video><i class="qrframe"></i></div><p class="note" style="text-align:center">მიუშვირე კამერა მეგობრის QR კოდს</p></div>`,()=>{alive=false;stream.getTracks().forEach(x=>x.stop())});
 const v=$('#qrv');v.srcObject=stream;let warned=0;
 const tick=async()=>{if(!alive)return;try{const r=await det.detect(v),raw=r&&r[0]&&r[0].rawValue;if(raw){const m=String(raw).match(/#user-([0-9a-f-]{36})/);if(m){closeLayer();closeSheet(true);openPage('user',m[1]);return}if(Date.now()-warned>3000){warned=Date.now();toast('ეს სუფრის QR კოდი არ არის')}}}catch(e){}setTimeout(tick,350)};
 v.onloadeddata=tick};

/* ---------- badges: earned on the server, each with a few coins ---------- */
const BADGES={post1:['✍️','პირველი პოსტი','დაწერე პირველი პოსტი',10],story1:['📸','პირველი ისტორია','გამოაქვეყნე ისტორია',10],friends10:['🤝','10 მეგობარი','იყოლიე 10 მეგობარი',20],grader:['⭐','შემფასებელი','შეაფასე 50 ფოტო',20],star:['🌟','ვარსკვლავი','შენს ფოტოებს 10-ჯერ დაუწერეს „5+“',30],host:['🏡','მასპინძელი','გამართე ღონისძიება',20],tamada:['🥂','თამადა','იყავი თამადა ღონისძიებაზე',30],supra:['🎥','სუფრის გამშლელი','გაშალე ვირტუალური სუფრა',15],nardi:['🎲','ნარდის ოსტატი','მიაღწიე 1600 რეიტინგს თამაშებში',30],helper:['❤️','კეთილი გული','გამოეხმაურე დახმარების თხოვნას',20],cook:['🥟','მზარეული','დაამატე რეცეპტი სამზარეულოში',15],verified:['✅','ვერიფიცირებული','დაადასტურე, რომ ფოტოებზე შენ ხარ',10],album:['🖼️','მემატიანე','შექმენი საერთო ალბომი',10]};
let BDG_AT=0;
async function checkBadges(force){if(!ME||(!force&&Date.now()-BDG_AT<120000))return [];BDG_AT=Date.now();
 try{const got=await rpc('check_achievements')||[];if(got.length){const sum=got.reduce((a,c)=>a+(BADGES[c]?BADGES[c][3]:0),0);if(typeof setCoins==='function')setCoins((ME.coins||0)+sum);
   got.forEach((c,i)=>setTimeout(()=>{const b=BADGES[c];if(!b)return;toast(`${b[0]} ახალი ნიშანი: ${b[1]} · +${b[3]} მონეტა`);confetti()},i*3000))}return got}catch(e){return []}}
async function loadBadges(uid,el=$('#bdgrow')){if(!el)return;const mine=uid===ME.id;
 try{if(mine)await checkBadges(true);const rows=await q(sb.from('achievements').select('code,created_at').eq('user_id',uid).order('created_at'));if(!el.isConnected)return;
  const got=rows.filter(r=>BADGES[r.code]),n=got.length,all=Object.keys(BADGES).length;if(!n&&!mine){el.innerHTML='';return}
  el.innerHTML=`<button class="bdgs" data-a="badges" data-u="${uid}"><span class="bdgh"><b>ნიშნები</b><em>${n}/${all}</em>${ic('back')}</span><span class="bdgl">${n?got.map(r=>`<span class="bdg" title="${esc(BADGES[r.code][1])}">${BADGES[r.code][0]}</span>`).join(''):'<span class="note">ჯერ არცერთი. ნახე, როგორ მოიპოვო</span>'}</span></button>`}
 catch(e){el.innerHTML=''}}
A.badges=async t=>{const uid=t.dataset.u||ME.id,mine=uid===ME.id;let rows=[];try{rows=await q(sb.from('achievements').select('code,created_at').eq('user_id',uid))}catch(e){}
 const has=new Map(rows.map(r=>[r.code,r.created_at])),keys=Object.keys(BADGES).filter(k=>mine||has.has(k));
 sheet(head(mine?'ჩემი ნიშნები':'ნიშნები · '+esc(String(pname(uid)).split(' ')[0]))+`<div class="ph-body"><div class="bdggrid">${keys.map(k=>{const b=BADGES[k],on=has.has(k);return `<div class="bdgc${on?' on':''}"><span class="bdgi">${b[0]}</span><b>${b[1]}</b><small>${on?'მოპოვებულია '+fdate(has.get(k)):esc(b[2])}</small><em>+${b[3]} ${ic('coin')}</em></div>`}).join('')}</div></div>`)};

/* ---------- topics: followed hashtags shape "for you" ---------- */
const TOPICS=[['ღვინო','🍷',['ღვინო','მარანი','რთველი','ქვევრი']],['ფეხბურთი','⚽',['ფეხბურთი','ეროვნული','სპორტი']],['მოგზაურობა','🧭',['მოგზაურობა','მთა','ზღვა','ლაშქრობა']],['სამზარეულო','🥟',['რეცეპტი','ხინკალი','ხაჭაპური','სამზარეულო']],['ოჯახი','👪',['ოჯახი','ბავშვები']],['მუსიკა','🎶',['მუსიკა','პოლიფონია','სიმღერა']],['ისტორია','📜',['ისტორია','ძველი']],['თამაშები','🎲',['ნარდი','ჭადრაკი','ჯოკერი']],['ბუნება','🌿',['ბუნება','ცხოველები']],['ხელოვნება','🎨',['ხელოვნება','ფოტო']],['ბიზნესი','💼',['ბიზნესი','სამსახური']],['დღესასწაულები','🕯️',['დღესასწაული','ეკლესია']]];
let TAGF=new Set(),TAGF_AT=0;
async function loadTagFollows(force){if(!ME||(!force&&TAGF_AT))return TAGF;TAGF_AT=Date.now();try{const r=await q(sb.from('tag_follows').select('tag').eq('user_id',ME.id));TAGF=new Set(r.map(x=>x.tag))}catch(e){}return TAGF}
const normTag=t=>String(t||'').trim().replace(/^#+/,'').toLowerCase();
async function followTags(tags,on){tags=tags.map(normTag).filter(Boolean);
 if(on){const add=tags.filter(t=>!TAGF.has(t));if(add.length)await q(sb.from('tag_follows').insert(add.map(tag=>({user_id:ME.id,tag}))));add.forEach(t=>TAGF.add(t))}
 else{await q(sb.from('tag_follows').delete().eq('user_id',ME.id).in('tag',tags));tags.forEach(t=>TAGF.delete(t))}}
A.topics=async()=>{await loadTagFollows(true);let changed=false;
 const draw=()=>{const el=$('#tpb');if(!el)return;const extra=[...TAGF].filter(t=>!TOPICS.some(x=>x[2].includes(t)));
  el.innerHTML=`<p class="note">აირჩიე, რა გაინტერესებს. „შენთვის“ ფიდში ამ თემების პოსტები უფრო ხშირად და უფრო მაღლა გამოჩნდება.</p><div class="tpgrid">${TOPICS.map(([n,e,tags],i)=>`<button type="button" class="tpc" data-i="${i}" aria-pressed="${tags.every(t=>TAGF.has(t))}"><span>${e}</span>${n}</button>`).join('')}</div>
   <h4 class="sec3">ჩემი ჰეშთეგები</h4><div class="chips tpmine">${extra.map(t=>`<button type="button" class="chip" data-rm="${esc(t)}">#${esc(t)} ${ic('x')}</button>`).join('')||'<span class="note">ჯერ არცერთი. ჰეშთეგის გვერდზეც შეგიძლია „გამოწერა“.</span>'}</div>
   <form class="row2" id="tpf"><input class="field" id="tpi" maxlength="40" placeholder="#ჰეშთეგი, მაგ. სვანეთი"><button class="btn sm">${ic('plus')}დამატება</button></form>`;
  $$('.tpc',el).forEach(b=>b.onclick=async()=>{const[, ,tags]=TOPICS[+b.dataset.i],on=b.getAttribute('aria-pressed')!=='true';b.setAttribute('aria-pressed',String(on));try{await followTags(tags,on);changed=true}catch(e){toast(errMsg(e))}draw()});
  $$('[data-rm]',el).forEach(b=>b.onclick=async()=>{try{await followTags([b.dataset.rm],false);changed=true;draw()}catch(e){toast(errMsg(e))}});
  $('#tpf').onsubmit=async e=>{e.preventDefault();const v=normTag($('#tpi').value);if(!v)return;try{await followTags([v],true);changed=true;draw()}catch(x){toast(errMsg(x))}}};
 sheet(head('ჩემი თემები')+`<div class="ph-body" id="tpb"></div>`,'',()=>{if(changed&&S.tab==='home'&&!S.page){$('#feed')&&($('#feed').innerHTML=skel(3));loadFeed(true)}});draw()};
A.tagfollow=async t=>{const tag=normTag(t.dataset.t),on=!TAGF.has(tag);try{await followTags([tag],on);t.outerHTML=tagFollowBtn(tag);toast(on?`#${tag} გამოწერილია. მეტს ნახავ „შენთვის“ ფიდში`:'გამოწერა გაუქმდა')}catch(e){toast(errMsg(e))}};
const tagFollowBtn=tag=>`<button class="btn sm${TAGF.has(normTag(tag))?' ghost':''}" data-a="tagfollow" data-t="${esc(tag)}">${TAGF.has(normTag(tag))?ic('check')+'გამოწერილია':ic('plus')+'გამოწერა'}</button>`;

/* ---------- saved folders ---------- */
let FOLDERS=null;
async function loadFolders(force){if(FOLDERS&&!force)return FOLDERS;try{FOLDERS=await q(sb.from('save_folders').select('id,name').eq('user_id',ME.id).order('created_at'))}catch(e){FOLDERS=FOLDERS||[]}return FOLDERS}
/* right after saving, a banner offers to put the post into a folder */
function savedBanner(pid){banner(`<span class="sbic">${ic('bookmark','currentColor')}</span><span class="grow"><b>შენახულია</b><span>შეეხე, რომ საქაღალდეში ჩადო</span></span>`,()=>folderPick(pid))}
async function folderPick(pid){const fs=await loadFolders();
 sheet(head('საქაღალდეში შენახვა')+`<div class="ph-body"><div class="list">${[{id:'',name:'საქაღალდის გარეშე'},...fs].map(f=>`<button class="row" data-a="savefolder" data-pid="${pid}" data-f="${f.id}"><span class="fico">${ic(f.id?'bookmark':'grid')}</span><span class="grow"><b>${esc(f.name)}</b></span></button>`).join('')}</div>
  <form class="row2" id="fnf"><input class="field" id="fnn" maxlength="40" placeholder="ახალი საქაღალდე, მაგ. რეცეპტები"><button class="btn sm">${ic('plus')}შექმნა</button></form></div>`,'short');
 $('#fnf').onsubmit=async e=>{e.preventDefault();const name=$('#fnn').value.trim();if(!name)return;try{const f=await q(sb.from('save_folders').insert({user_id:ME.id,name}).select('id,name').single());FOLDERS=[...(FOLDERS||[]),f];await q(sb.from('saves').update({folder_id:f.id}).eq('user_id',ME.id).eq('post_id',pid));closeSheet();toast(`ჩაიდო საქაღალდეში „${name}“`)}catch(x){toast(errMsg(x))}}}
A.savefolder=async t=>{const f=t.dataset.f?+t.dataset.f:null;try{await q(sb.from('saves').update({folder_id:f}).eq('user_id',ME.id).eq('post_id',+t.dataset.pid));closeSheet();toast(f?'ჩაიდო საქაღალდეში':'შენახულია საქაღალდის გარეშე')}catch(e){toast(errMsg(e))}};
/* the saved posts, with folder chips on top; used by the saved page (list) and the profile tab (grid) */
let SAVF='';
async function savedView(el,grid){if(!el)return;const fs=await loadFolders(true);if(SAVF&&!fs.some(f=>String(f.id)===String(SAVF)))SAVF='';
 el.innerHTML=`<div class="chipsbar savchips" role="group" aria-label="საქაღალდეები" style="padding-top:12px"><button data-a="savf" data-f="" aria-pressed="${!SAVF}">ყველა</button>${fs.map(f=>`<button data-a="savf" data-f="${f.id}" aria-pressed="${String(SAVF)===String(f.id)}">${esc(f.name)}</button>`).join('')}${SAVF?`<button data-a="savfmenu" data-f="${SAVF}" aria-label="საქაღალდის მართვა">${ic('more')}</button>`:''}</div><div class="savbody">${skel(2)}</div>`;
 el.dataset.grid=grid?'1':'';const body=$('.savbody',el);
 try{let b=sb.from('saves').select('post_id').eq('user_id',ME.id).order('created_at',{ascending:false}).limit(90);if(SAVF)b=b.eq('folder_id',+SAVF);const s=await q(b);const ids=s.map(x=>x.post_id);
  const rows=ids.length?await fetchPosts(x=>x.in('id',ids)):[];rows.sort((a,c)=>ids.indexOf(a.id)-ids.indexOf(c.id));if(!body.isConnected)return;
  body.innerHTML=rows.length?(grid?gridHTML(rows):rows.map(postHTML).join('')):empty(SAVF?'ეს საქაღალდე ცარიელია':'შენახული ჯერ არაფერია',SAVF?'პოსტის შენახვისას ზემოთ ამოვა ღილაკი „საქაღალდეში“.':'პოსტთან სანიშნეს დააჭირე და აქ გამოჩნდება.')}
 catch(e){body.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
A.savf=t=>{SAVF=t.dataset.f;const el=t.closest('.savwrap');savedView(el,!!el?.dataset.grid)};
A.savfmenu=t=>{const id=+t.dataset.f,f=(FOLDERS||[]).find(x=>x.id===id);if(!f)return;
 sheet(head(esc(f.name))+`<form class="ph-body" id="frf"><label class="fld">სახელი<input id="frn" maxlength="40" value="${esc(f.name)}"></label><div class="row2"><button class="btn">შენახვა</button><button type="button" class="btn ghost warnbtn" id="frd">საქაღალდის წაშლა</button></div><p class="note">წაშლისას პოსტები შენახულში დარჩება.</p></form>`,'short');
 $('#frf').onsubmit=async e=>{e.preventDefault();const v=$('#frn').value.trim();if(!v)return;try{await q(sb.from('save_folders').update({name:v}).eq('id',id));closeSheet();FOLDERS=null;const w=$('.savwrap');if(w)savedView(w,!!w.dataset.grid)}catch(x){toast(errMsg(x))}};
 $('#frd').onclick=async()=>{try{await q(sb.from('save_folders').delete().eq('id',id));SAVF='';closeSheet();FOLDERS=null;const w=$('.savwrap');if(w)savedView(w,!!w.dataset.grid)}catch(x){toast(errMsg(x))}}};
