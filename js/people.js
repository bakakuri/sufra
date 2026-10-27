/* people: profiles, friends, notifications, stories, clips, gifts, block, report */
let FRIENDS=new Set(),PENDING_IN=new Set(),PENDING_OUT=new Set(),BLOCKED=new Set();
async function loadFriends(){try{const rows=await q(sb.from('friendships').select('requester,addressee,status').or(`requester.eq.${ME.id},addressee.eq.${ME.id}`));
 FRIENDS=new Set();PENDING_IN=new Set();PENDING_OUT=new Set();rows.forEach(r=>{const o=r.requester===ME.id?r.addressee:r.requester;if(r.status==='accepted')FRIENDS.add(o);else if(r.addressee===ME.id)PENDING_IN.add(o);else PENDING_OUT.add(o)});
 const b=await q(sb.from('blocks').select('blocked').eq('blocker',ME.id));BLOCKED=new Set(b.map(x=>x.blocked));await loadProfiles([...FRIENDS,...PENDING_IN]);renderBadges()}catch(e){}}
function friendBtn(id){if(id===ME.id)return '';if(FRIENDS.has(id))return `<button class="btn ghost" data-a="friendmenu" data-u="${id}">${ic('check')}მეგობრები</button>`;
 if(PENDING_IN.has(id))return `<button class="btn" data-a="acceptfriend" data-u="${id}">დადასტურება</button>`;if(PENDING_OUT.has(id))return `<button class="btn ghost" data-a="cancelfriend" data-u="${id}">მოთხოვნა გაგზავნილია</button>`;
 return `<button class="btn" data-a="addfriend" data-u="${id}">${ic('plus')}მეგობრად დამატება</button>`}
A.addfriend=async t=>{const id=t.dataset.u;t.disabled=true;try{if(PENDING_IN.has(id)){await A.acceptfriend(t);return}await q(sb.from('friendships').insert({requester:ME.id,addressee:id}));PENDING_OUT.add(id);t.outerHTML=friendBtn(id).replace('class="btn ghost"','class="btn ghost sm"');toast('მოთხოვნა გაიგზავნა');burst(t)}catch(e){toast(errMsg(e));t.disabled=false}};
A.acceptfriend=async t=>{const id=t.dataset.u;try{await q(sb.from('friendships').update({status:'accepted'}).eq('requester',id).eq('addressee',ME.id));PENDING_IN.delete(id);FRIENDS.add(id);renderBadges();toast('ახლა მეგობრები ხართ');confetti();if(S.page)rp()}catch(e){toast(errMsg(e))}};
A.declinefriend=async t=>{const id=t.dataset.u;try{await q(sb.from('friendships').delete().eq('requester',id).eq('addressee',ME.id));PENDING_IN.delete(id);renderBadges();rp()}catch(e){toast(errMsg(e))}};
A.cancelfriend=async t=>{const id=t.dataset.u;try{await q(sb.from('friendships').delete().eq('requester',ME.id).eq('addressee',id));PENDING_OUT.delete(id);rp()}catch(e){toast(errMsg(e))}};
A.friendmenu=t=>{const id=t.dataset.u;sheet(head(esc(pname(id)))+`<div class="reasons"><button data-a="chatwith" data-u="${id}">შეტყობინება</button><button data-a="gift" data-u="${id}">საჩუქრის გაგზავნა</button><button class="warnbtn" data-a="unfriend" data-u="${id}">მეგობრობის გაუქმება</button></div>`,'short')};
A.unfriend=t=>{const id=t.dataset.u;confirmSheet('მეგობრობის გაუქმება',`${esc(pname(id))} აღარ იქნება შენს მეგობრებში.`,'გაუქმება',async()=>{await q(sb.from('friendships').delete().or(`and(requester.eq.${ME.id},addressee.eq.${id}),and(requester.eq.${id},addressee.eq.${ME.id})`));FRIENDS.delete(id);rp()},true)};

/* profile page */
R.me=()=>{view.innerHTML=`<div id="ub">${skel(2)}</div>`;loadUser(ME.id)};
PG.user={r(id){const mine=id===ME.id;view.innerHTML=(mine&&!S.page?'':pgHead(''))+`<div id="ub">${skel(2)}</div>`;loadUser(id)}};
const PTABS_ME=[['posts','grid','პოსტები'],['albums','image','ალბომები'],['cv','school','CV'],['saved','bookmark','შენახული']];
const PTABS_OTHER=[['posts','grid','პოსტები'],['albums','image','ალბომები'],['friends','users','მეგობრები'],['cv','school','CV']];
const myTiles=()=>[['page','storyarch','story','ისტორიების არქივი'],['page','friends','users','მეგობრები',PENDING_IN.size],['page','drafts','clock','დრაფტები'],['page','close','star','ახლო მეგობრები'],['ptsheet','guests','eye','სტუმრები'],['ptsheet','gifts','gift','საჩუქრები'],['page','coins','coin','მონეტები'],['tree','','tree','ოჯახის ხე'],['page','namedays','cal','ანგელოზის დღე']];
async function loadUser(id){const mine=id===ME.id;let p;try{if(mine){ME=await rpc('my_profile');p=ME}else{const d=await q(sb.from('profiles').select(PCOLS).eq('id',id).maybeSingle());if(!d){$('#ub').innerHTML=empty('პროფილი ვერ მოიძებნა');return}PC.set(id,d);p=d}}catch(e){const u=$('#ub');if(u)u.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e));return}
 if(!mine&&!ME.privacy?.guest)sb.from('profile_visits').upsert({visitor:ME.id,visited:id,visited_at:new Date().toISOString()},{onConflict:'visitor,visited'}).then(()=>{});
 let nf=0,np=0,mut=0;try{const[f,c,m]=await Promise.all([sb.from('friendships').select('requester',{count:'exact',head:true}).eq('status','accepted').or(`requester.eq.${id},addressee.eq.${id}`),sb.from('posts').select('id',{count:'exact',head:true}).eq('author',id).eq('draft',false),mine?Promise.resolve(0):rpc('mutual_friends',{other:id})]);nf=f.count||0;np=c.count||0;mut=m||0}catch(e){}
 const tabs=mine?PTABS_ME:PTABS_OTHER;if(!tabs.find(t=>t[0]===S.ptab))S.ptab='posts';
 const ub=$('#ub');if(!ub)return;const blocked=BLOCKED.has(id),nd=nameDaysOf(p).map(([md])=>Object.assign({md},nextDate(md))).sort((a,b)=>a.n-b.n)[0];
 const role=p.role==='admin'?'ადმინისტრატორი':p.role==='moderator'?'მოდერატორი':'';
 ub.innerHTML=`<div class="pcov${mine?' own':''}"${mine?' data-a="epcover" role="button" tabindex="0" aria-label="ფონის შეცვლა"':''}>${p.cover_url?`<img src="${esc(p.cover_url)}" alt="">`:`<img src="${art('mtn',(p.hue||7)+11,560,200)}" alt="">`}${mine?`<span class="pcam">${ic('camera')}ფონის შეცვლა</span>`:''}</div>
 <section class="pro2"><div class="pro2top"><button class="pav2" data-a="${mine?'epavatar':'avview'}" data-u="${id}" aria-label="${mine?'პროფილის ფოტოს შეცვლა':'ფოტოს ნახვა'}">${av(p,104)}${mine?`<span class="pcam2">${ic('camera')}</span>`:isOnline(id)?'<i class="ond big" aria-label="ონლაინ"></i>':''}</button>
</div>
  <h1 class="pro2n">${esc(p.name)}${vb(p)}</h1>
  <p class="pro2m">${[p.username?'@'+esc(p.username):'',p.city?ic('pin')+esc(p.city):'',!mine&&isOnline(id)?'<i class="ond"></i>ონლაინ':'',role,p.banned?'შეზღუდულია':''].filter(Boolean).join('<span class="dotsep">·</span>')}</p>
  ${p.bio?tx(p.bio):''}
  ${p.surname||nd||p.home_place?`<div class="pchips">${p.surname?`<button class="pchip" data-a="surname" data-s="${esc(p.surname)}">${ic('users')}გვარი: ${esc(p.surname)}</button>`:''}${nd?`<span class="pchip">${ic('cal')}ანგელოზის დღე: ${mdTxt(nd.md)}</span>`:''}${p.home_place?`<span class="pchip">${ic('pin')}${esc(p.home_place)}</span>`:''}</div>`:''}
  <div class="pro2row">${mine?`<button class="btn" data-a="editprofile">${ic('edit')}რედაქტირება</button><button class="btn ghost" data-a="page" data-p="settings">${ic('gear')}პარამეტრები</button><button class="ibtn sq" data-a="sharepro" data-u="${id}" aria-label="პროფილის გაზიარება">${ic('share')}</button>`
   :blocked?`<button class="btn ghost" data-a="unblock" data-u="${id}">განბლოკვა</button><button class="ibtn sq" data-a="umore" data-u="${id}" aria-label="მეტი">${ic('more')}</button>`:`${friendBtn(id)}<button class="btn ghost" data-a="chatwith" data-u="${id}">${ic('msg')}მიწერა</button><button class="ibtn sq" data-a="umore" data-u="${id}" aria-label="მეტი">${ic('more')}</button>`}</div>
  <div id="hlrow"></div>
  <div class="stats2"><button data-a="pstat" data-k="posts" data-u="${id}"><b>${fmt(np)}</b><span>პოსტი</span></button><button data-a="pstat" data-k="friends" data-u="${id}"><b>${fmt(nf)}</b><span>მეგობარი</span></button><button data-a="pstat" data-k="games" data-u="${id}"><b>${p.rating??1500}</b><span>რეიტინგი</span></button><button data-a="pstat" data-k="${mine?'coins':'mutual'}" data-u="${id}"><b>${mine?(p.coins??0):mut}</b><span>${mine?'მონეტა':'საერთო'}</span></button></div><div id="bdgrow"></div></section>
 ${mine?`${!p.verified||isStaff()?`<div class="pbanners">${!p.verified?`<button class="pbanner" data-a="page" data-p="verify">${ic('shield')}<span class="grow"><b>ვერიფიკაცია</b><small>მიიღე ✓ ნიშანი და მეტი ნდობა</small></span>${ic('back')}</button>`:''}${isStaff()?`<button class="pbanner adm" data-a="page" data-p="admin">${ic('shield')}<span class="grow"><b>ადმინ პანელი</b><small>საჩივრები, ვერიფიკაცია, რეკლამა</small></span>${ic('back')}</button>`:''}</div>`:''}
  <nav class="ptiles" aria-label="ჩემი სივრცე">${myTiles().map(([a,pg,i,l,badge])=>`<button data-a="${a}" ${a==='page'?`data-p="${pg}"`:a==='ptsheet'?`data-k="${pg}"`:''}><span class="pti">${ic(i)}${badge?`<i class="badge">${badge}</i>`:''}</span><span>${l}</span></button>`).join('')}</nav>`:''}
 <div class="ptabs2" role="tablist">${tabs.map(([k,i,l])=>`<button role="tab" data-a="ptab" data-p="${k}" data-u="${id}" aria-selected="${S.ptab===k}">${ic(i)}<span>${l}</span></button>`).join('')}</div><div id="ptabb">${skel(2)}</div>`;
 const h=$('.pghead h2');if(h)h.textContent=p.name;loadPTab(id);loadHighlights(id);loadBadges(id)}
A.ptab=t=>{S.ptab=t.dataset.p;$$('[data-a="ptab"]').forEach(b=>b.setAttribute('aria-selected',String(b===t)));loadPTab(t.dataset.u)};
A.pstat=t=>{const k=t.dataset.k,u=t.dataset.u;if(k==='games')return typeof gCardOpen==='function'?gCardOpen(u||ME.id):go('games');if(k==='coins')return openPage('coins');if(k==='friends'&&u===ME.id)return openPage('friends');
 const tab=k==='mutual'?'friends':k;const b=$(`[data-a="ptab"][data-p="${tab}"]`);if(b){A.ptab(b);b.scrollIntoView({block:'start',behavior:RM()?'auto':'smooth'})}};
A.ptsheet=t=>{const k=t.dataset.k;if(k==='guests')guestsSeen();sheet(head(k==='guests'?'სტუმრები':'საჩუქრები')+`<div class="ph-body" id="ptsb" style="padding:0">${skel(3)}</div>`);loadPTab(ME.id,k,$('#ptsb'))};
A.avview=t=>{const p=prof(t.dataset.u);if(p.avatar_url)openImage(p.avatar_url)};
/* the posts of a profile are shown as a grid, as on other networks; a tap opens the viewer */
function gridHTML(rows){return `<div class="pgrid2">${rows.map(p=>{const ms=pmedia(p),m=ms.find(x=>x.type==='image')||ms[0],h=((p.ap||prof(p.author)).hue??200)%360;
 const inner=m&&!ECO()?(m.type==='video'?(mPoster(m)?`<img src="${esc(mPoster(m))}" alt="" loading="lazy" decoding="async">`:`<video src="${esc(m.url)}" muted playsinline preload="metadata"></video>`):`<img src="${esc(mSm(m))}" alt="" loading="lazy" decoding="async">`):`<span class="pgtext" style="--h:${h}">${m?ic(m.type==='video'?'clips':'image'):esc(String(p.body||'').slice(0,140))}</span>`;
 const badge=ms.length>1?`<span class="pgb">${ic('image')}${ms.length}</span>`:m&&m.type==='video'?`<span class="pgb">${ic('clips')}</span>`:p.poll?`<span class="pgb">${ic('poll')}</span>`:'';
 return `<button class="pgt${p.hidden?' is-hidden':''}" data-a="pvopen" data-pid="${p.id}" aria-label="პოსტის გახსნა">${inner}${badge}${gridGrade(p,STAT.get(p.id))}</button>`}).join('')}</div>`}
/* a photo tile carries its grade: the average when it has one, otherwise an invitation to grade someone else's photo */
function gridGrade(p,s){if(!pmedia(p).some(x=>x.type==='image'))return '';s=s||blankStat(p.id);
 if(s.my_grade)return `<span class="pgg on">${ic('star','currentColor')}${s.my_grade}${s.grade_n>1?`<small>${s.grade_avg}</small>`:''}</span>`;
 if(s.grade_n)return `<span class="pgg">${ic('star','currentColor')}${s.grade_avg}<small>${s.grade_n}</small></span>`;
 return p.author===ME.id?'':`<span class="pgg new">${ic('star')}შეაფასე</span>`}
async function loadPTab(id,k=S.ptab,el=$('#ptabb')){if(!el)return;el.innerHTML=skel(2);
 try{if(k==='posts'){const rows=await fetchPosts(b=>b.eq('author',id).is('group_id',null).is('repost_of',null).order('created_at',{ascending:false}).limit(60));if(!el.isConnected)return;el.innerHTML=rows.length?gridHTML(rows):empty(id===ME.id?'ჯერ არაფერი დაგიწერია':'პოსტები ჯერ არ არის',id===ME.id?'გაუზიარე მეგობრებს პირველი ფიქრი ან ფოტო.':'',id===ME.id?'<button class="btn" data-a="compose">პოსტის დაწერა</button>':'');staggerIn($$('.pgt',el).slice(0,9),25,40)}
  else if(k==='saved'){el.innerHTML='<div class="savwrap"></div>';await savedView($('.savwrap',el),true)}
  else if(k==='albums')await profileAlbums(id,el);
  else if(k==='friends'){const rows=await q(sb.from('friendships').select('requester,addressee').eq('status','accepted').or(`requester.eq.${id},addressee.eq.${id}`).limit(200));const ids=rows.map(r=>r.requester===id?r.addressee:r.requester);await loadProfiles(ids);el.innerHTML=ids.length?`<div class="list" style="padding-top:8px">${ids.map(x=>personRow(prof(x))).join('')}</div>`:empty('მეგობრები ჯერ არ არის')}
  else if(k==='guests'){const rows=await q(sb.from('profile_visits').select('visitor,visited_at').eq('visited',ME.id).order('visited_at',{ascending:false}).limit(50));await loadProfiles(rows.map(r=>r.visitor));
   el.innerHTML=`<p class="hint" style="padding:12px 16px">ვინ ნახა შენი გვერდი${ME.privacy?.guest?'. უხილავი რეჟიმი ჩართულია: შენ სხვების სტუმრებში არ ჩანხარ':''}</p>`+(rows.length?`<div class="list">${rows.map(r=>`<button class="row" data-a="user" data-u="${r.visitor}">${av(r.visitor,44)}<span class="grow"><b>${esc(pname(r.visitor))}${vb(r.visitor)}</b><span class="sub">${ago(r.visited_at)}</span></span>${ic('eye')}</button>`).join('')}</div>`:empty('სტუმრები ჯერ არ ყოფილან'))}
  else if(k==='gifts'){const rows=await q(sb.from('gifts').select('emoji,sender,created_at').eq('recipient',ME.id).order('created_at',{ascending:false}).limit(60));await loadProfiles(rows.map(r=>r.sender));el.innerHTML=rows.length?`<div class="gifts">${rows.map(r=>`<div class="gift">${r.emoji}<small>${esc(String(pname(r.sender)).split(' ')[0])}</small></div>`).join('')}</div>`:empty('საჩუქრები ჯერ არ მიგიღია')}
  else if(k==='cv'){const cv=await q(sb.from('cvs').select('*').eq('user_id',id).maybeSingle());el.innerHTML=cv&&(cv.visible||id===ME.id)?`<div class="cvwrap">${id===ME.id?`<div class="cvbar"><span class="cvvis${cv.visible?' on':''}">${ic(cv.visible?'eye':'lock')}${cv.visible?'ყველა ხედავს':'მხოლოდ დამსაქმებლები ხედავენ'}</span><button class="btn sm ghost" data-a="page" data-p="cv">${ic('edit')}რედაქტირება</button></div>`:''}${cvHTML(cv,id)}</div>`:empty(id===ME.id?'CV ჯერ არ გაქვს':'CV არ არის გამოქვეყნებული',id===ME.id?'შექმენი და ვაკანსიებზე ერთი შეხებით გამოეხმაურე.':'',id===ME.id?'<button class="btn" data-a="page" data-p="cv">CV-ის შექმნა</button>':'')}}
 catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
A.openpost=t=>openPage('post',pidOf(t));
/* photo and cover change straight from the profile */
async function setMyPic(kind){const cover=kind==='cover';const b=await pickImage(cover?{ratios:['169'],ratio:'169',max:1400,title:'ფონის ფოტო'}:{ratios:['1'],ratio:'1',max:640,title:'პროფილის ფოტო'});if(!b)return;
 try{toast('იტვირთება…');const url=await uploadBlob(b,'jpg');const upd=cover?{cover_url:url}:{avatar_url:url};await q(sb.from('profiles').update(upd).eq('id',ME.id));Object.assign(ME,upd);toast(cover?'ფონი შეიცვალა':'ფოტო შეიცვალა');renderTop();renderSide();if(S.tab==='me'&&!S.page||S.page?.id==='user')loadUser(ME.id)}catch(e){toast(errMsg(e))}}
A.epcover=()=>setMyPic('cover');
A.epavatar=()=>setMyPic('avatar');
A.editprofile=()=>{const p=ME;sheet(head('პროფილის რედაქტირება')+`<form class="ph-body" id="epf">
 <div class="epcov" data-a="epcover2" role="button" aria-label="ფონის შეცვლა">${p.cover_url?`<img src="${esc(p.cover_url)}" alt="">`:`<img src="${art('mtn',(p.hue||7)+11,560,200)}" alt="">`}<span class="pcam">${ic('camera')}ფონი</span><button type="button" class="epav" id="ep_av" aria-label="ფოტოს შეცვლა">${av(p,76)}<span>${ic('camera')}</span></button></div>
 <h3 class="epsec">ძირითადი</h3>
 <label class="fld">სახელი და გვარი<input id="ep_n" maxlength="60" required value="${esc(p.name)}"></label>
 <div class="frow"><label class="fld">მომხმარებლის სახელი<input id="ep_u" maxlength="24" pattern="[a-z0-9_.]{3,24}" value="${esc(p.username||'')}" autocapitalize="none" placeholder="მაგ. giorgi"></label><label class="fld">გვარი<input id="ep_sn" maxlength="40" value="${esc(p.surname||lastWord(p.name))}" placeholder="გვარის ჯგუფისთვის"></label></div>
 <label class="fld">ჩემ შესახებ<textarea id="ep_b" maxlength="300" rows="3" placeholder="ორიოდე სიტყვა შენზე">${esc(p.bio||'')}</textarea></label>
 <h3 class="epsec">სად ვარ</h3>
 <label class="fld">ქალაქი<input id="ep_c" list="cities2" maxlength="60" value="${esc(p.city||'')}"></label><datalist id="cities2">${CITIES.map(c=>`<option value="${c}">`).join('')}</datalist>
 <div class="frow"><label class="fld">მშობლიური კუთხე<select id="ep_r"><option value="">—</option>${REGIONS.map(r=>`<option${p.home_region===r?' selected':''}>${r}</option>`).join('')}</select></label><label class="fld">სოფელი ან ქალაქი<input id="ep_pl" maxlength="60" value="${esc(p.home_place||'')}" placeholder="მაგ. სიღნაღი"></label></div>
 <label class="fld">ემიგრაციაში ვარ<select id="ep_ab"><option value="">არა</option>${ABROAD.map(c=>`<option${p.abroad===c?' selected':''}>${c}</option>`).join('')}</select></label>
 <h3 class="epsec">სხვა</h3>
 <div class="fld">ანგელოზის დღე<button type="button" class="btn sm ghost" data-a="setnd" style="align-self:flex-start">${ic('cal')}${p.nameday?mdTxt(p.nameday):'მითითება'}</button></div>
 <label class="chk"><input type="checkbox" id="ep_biz"${p.is_business?' checked':''}><span>ბიზნეს ანგარიში (გვერდები და რეკლამა)</span></label>
 <p class="note">პირადი ინფორმაციის, შეტყობინებების და უსაფრთხოების პარამეტრები „პარამეტრებშია“.</p></form><div class="ph-foot"><button class="btn ghost" data-a="page" data-p="settings">${ic('gear')}პარამეტრები</button><span class="sp"></span><button class="btn" id="ep_save">შენახვა</button></div>`);
 const upd={};
 const pickAv=async()=>{const b=await pickImage({ratios:['1'],ratio:'1',max:640,title:'პროფილის ფოტო'});if(!b)return;try{toast('იტვირთება…');upd.avatar_url=await uploadBlob(b,'jpg');$('#ep_av').innerHTML=`<img class="av" style="--s:76px" src="${upd.avatar_url}" alt=""><span>${ic('camera')}</span>`}catch(e){toast(errMsg(e))}};
 $('#ep_av').onclick=e=>{e.stopPropagation();pickAv()};
 A.epcover2=async()=>{const b=await pickImage({ratios:['169'],ratio:'169',max:1400,title:'ფონის ფოტო'});if(!b)return;try{toast('იტვირთება…');upd.cover_url=await uploadBlob(b,'jpg');const im=$('.epcov img');if(im)im.src=upd.cover_url}catch(e){toast(errMsg(e))}};
 $('#ep_u').oninput=e=>{e.target.value=e.target.value.toLowerCase().replace(/[^a-z0-9_.]/g,'')};
 $('#ep_save').onclick=async()=>{const b=$('#ep_save');b.disabled=true;Object.assign(upd,{name:$('#ep_n').value.trim()||p.name,username:$('#ep_u').value.trim()||null,bio:$('#ep_b').value.trim(),city:$('#ep_c').value.trim(),is_business:$('#ep_biz').checked,surname:$('#ep_sn').value.trim().replace(/\s+/g,' '),home_region:$('#ep_r').value,home_place:$('#ep_pl').value.trim(),abroad:$('#ep_ab').value});
  try{await q(sb.from('profiles').update(upd).eq('id',ME.id));Object.assign(ME,upd);closeSheet();toast('შენახულია');renderTop();renderSide();if(S.page?.id==='user'||S.tab==='me')loadUser(ME.id)}catch(e){toast(/unique|duplicate/i.test(e.message)?'ეს მომხმარებლის სახელი დაკავებულია':errMsg(e));b.disabled=false}}};

/* friends page */
PG.friends={r(){view.innerHTML=pgHead('მეგობრები',`<button class="ibtn" data-a="sharepro" data-u="${ME.id}" aria-label="QR კოდი: ჩემი და სკანირება">${ic('qr')}</button><button class="btn sm ghost" data-a="invite">${ic('send')}მოწვევა</button>`)+`<div id="frb">${skel(3)}</div>`;loadFriendsPage()}};
async function loadFriendsPage(){await loadFriends();const el=$('#frb');if(!el)return;let sug=[];try{sug=await rpc('friend_suggestions',{p_limit:15});sug.forEach(p=>PC.set(p.id,Object.assign(PC.get(p.id)||{},p)))}catch(e){}await loadProfiles([...PENDING_OUT]);
 el.innerHTML=(PENDING_IN.size?`<h3 class="sec2">მოთხოვნები · ${PENDING_IN.size}</h3><div class="list">${[...PENDING_IN].map(id=>`<div class="row">${av(id,48)}<button class="grow" data-a="user" data-u="${id}" style="text-align:left"><b>${esc(pname(id))}${vb(id)}</b><span class="sub">გინდა მეგობრობა</span></button><button class="btn sm" data-a="acceptfriend" data-u="${id}">დადასტურება</button><button class="btn sm ghost" data-a="declinefriend" data-u="${id}" aria-label="უარყოფა">${ic('x')}</button></div>`).join('')}</div>`:'')
 +(sug.length?`<h3 class="sec2">შეიძლება იცნობდე</h3><div class="list">${sug.map(p=>`<div class="row">${av(p,48)}<button class="grow" data-a="user" data-u="${p.id}" style="text-align:left"><b>${esc(p.name)}${vb(p)}</b><span class="sub">${p.mutual?p.mutual+' საერთო მეგობარი':esc(p.city||'სუფრაზეა')}</span></button>${friendBtn(p.id).replace('class="btn"','class="btn sm"')}</div>`).join('')}</div>`:'')
 +`<h3 class="sec2">შენი მეგობრები · ${FRIENDS.size}</h3>`+(FRIENDS.size?`<div class="list">${[...FRIENDS].map(id=>personRow(prof(id))).join('')}</div>`:empty('მეგობრები ჯერ არ გყავს','მოიწვიე ნაცნობები ან მოძებნე სახელით.','<button class="btn" data-a="search">ძიება</button>'))
 +(PENDING_OUT.size?`<h3 class="sec2">გაგზავნილი მოთხოვნები</h3><div class="list">${[...PENDING_OUT].map(id=>`<div class="row">${av(id,40)}<span class="grow"><b>${esc(pname(id))}</b></span><button class="btn sm ghost" data-a="cancelfriend" data-u="${id}">გაუქმება</button></div>`).join('')}</div>`:'')}

/* notifications */
const NOTE_TXT={promo:r=>r.text||'',admin_msg:r=>'სუფრის გუნდი: '+(r.text||''),admin_coins:r=>`${+r.coins>0?'+':''}${r.coins||0} მონეტა · ${r.note||''}`,story_mention:()=>'მოგნიშნა თავის ისტორიაზე',recipe_cook:()=>'შენი რეცეპტით მოამზადა კერძი 🍲',jk_invite:()=>'გეპატიჟება ჯოკერზე 🃏',grade_plus:r=>`შენს ფოტოს „5+“ დაუწერა${r.coins?` · +${r.coins} მონეტა`:''}`,mention:r=>`მოგიხსენია${r.comment?' კომენტარში':' პოსტში'}: ${r.text||''}`,msg_react:r=>`${r.emoji||'❤️'} შენს მესიჯზე: ${r.text||''}`,story_react:r=>`${r.emoji||'❤️'} შენს ისტორიაზე`,
 event_invite:r=>`გეპატიჟება: ${r.title||''}${r.at?' · '+fdate(r.at):''}`,event_soon:r=>`მალე იწყება: ${r.title||''}${r.at?' · '+fdate(r.at):''}`,album_invite:r=>`დაგამატა ალბომში „${r.title||''}“`,album_photo:r=>`ფოტოები დაამატა ალბომში „${r.title||''}“`,
 group_request:r=>`ითხოვს გაწევრიანებას: ${r.name||''}`,group_ok:r=>`მიგიღეს ჯგუფში: ${r.name||''}`,group_pending:r=>`პოსტი ელოდება დამტკიცებას: ${r.name||''}`,group_post_ok:r=>`შენი პოსტი დამტკიცდა: ${r.name||''}`,group_post_no:r=>`შენი პოსტი არ დამტკიცდა: ${r.name||''}`,group_admin:r=>`ადმინი გაგხადა: ${r.name||''}`,
 react:r=>`${r.emoji||'👍'} შენს პოსტზე`,repost:r=>r.quote?'გააზიარა შენი პოსტი თავისი სიტყვით':'გააზიარა შენი პოსტი',comment_reply:r=>`გიპასუხა კომენტარზე: ${r.text||''}`,comment_like:r=>`მოიწონა შენი კომენტარი: ${r.text||''}`,comment:r=>`დაწერა კომენტარი: ${r.text||''}`,friend_req:()=>'გიგზავნის მეგობრობის მოთხოვნას',friend_ok:()=>'დაადასტურა მეგობრობა',gift:r=>`გიგზავნის საჩუქარს ${r.emoji||'🎁'}`,match:()=>'წყვილი ხართ! მიწერე პირველმა',super:()=>'სუპერ მოწონება გამოგიგზავნა ⭐',verified:()=>'შენი პროფილი ვერიფიცირდა ✓',verify_rejected:()=>'ვერიფიკაცია ვერ დადასტურდა. სცადე ახალი სელფით',ad_ok:()=>'შენი რეკლამა დამტკიცდა',ad_rejected:()=>'რეკლამა არ დამტკიცდა, მონეტები დაგიბრუნდა',room_invite:r=>`გეპატიჟება ${r.kind==='birja'?'ბირჟაზე':r.kind==='live'?'ლაივზე':'სუფრაზე'}: ${r.title||''}`,bet_won:r=>`მოიგე ${r.coins||''} მონეტა · ${r.match||''} ${r.score||''}`,bet_lost:r=>`${r.match||''} ${r.score||''} · პროგნოზი არ გამართლდა`,bet_refund:r=>`${r.match||''} · მონეტები დაგიბრუნდა`,ride_req:r=>`ითხოვს ${r.seats||1} ადგილს · ${r.route||''}`,ride_ok:r=>`დაგიდასტურა ადგილი · ${r.route||''}`,ride_no:r=>`ადგილი ვერ დაგიდასტურა · ${r.route||''}`,ride_cancel:r=>`გააუქმა ჯავშანი · ${r.route||''}`,job_apply:r=>`გამოეხმაურა ვაკანსიას: ${r.title||''}`,job_invited:r=>`გასაუბრებაზე მიგიწვია: ${r.title||''}`,job_rejected:r=>`${r.title||''} · სხვა კანდიდატი შეირჩა`,nameday:r=>`· ${r.label||'ანგელოზის დღე'}${r.n>1?` · და კიდევ ${r.n-1} მეგობარი`:''}. მიულოცე!`,birthday:r=>`· დაბადების დღე${r.n>1?` · და კიდევ ${r.n-1} მეგობარი`:''}. მიულოცე! 🎉`,nameday_me:r=>`გილოცავ ანგელოზის დღეს! ${r.label||''}`,birthday_me:()=>'სუფრა გილოცავს დაბადების დღეს! 🎉',kin_req:()=>'გთავაზობს ოჯახის ხეში დაკავშირებას',kin_ok:()=>'დაადასტურა ნათესაობა',help_new:r=>`${r.kind==='blood'?'🩸 საჭიროა დონორი'+(r.blood?' '+r.blood:''):r.kind==='volunteer'?'🤝 საჭიროა მოხალისე':'🐾 '+(r.kind==='found_pet'?'ნაპოვნია ცხოველი':'დაიკარგა ცხოველი')}: ${r.title||''} · ${r.region||''}`,help_offer:r=>`გთავაზობს დახმარებას: ${r.title||''}`,help_done:r=>`${r.title||''} · მოგვარდა. მადლობა, რომ გამოეხმაურე`,live_start:r=>`ცოცხალ ეთერშია: ${r.title||''}`};
async function openNotes(){navMark('notes',openNotes);sheet(head('შეტყობინებები',`<button class="btn sm ghost" data-a="readall">ყველა წაკითხულია</button><button class="ibtn" data-a="nset" aria-label="შეტყობინებების პარამეტრები">${ic('gear')}</button>`)+`<div class="ph-body" id="nb">${skel(4)}</div>`);
 try{const rows=await q(sb.from('notifications').select('id,actor,kind,ref,read,created_at').neq('kind','message').order('created_at',{ascending:false}).limit(60));await loadProfiles(rows.map(r=>r.actor));
  const el=$('#nb');if(!el)return;el.innerHTML=rows.map(n=>`<button class="row note${n.read?'':' unread'}" data-a="note" data-id="${n.id}" data-k="${n.kind}" data-r='${esc(JSON.stringify(n.ref||{}))}' data-u="${n.actor||''}">${n.actor?av(n.actor,44):`<span class="av" style="--s:44px;--h:330">ს</span>`}<span class="grow"><span>${n.actor?`<b>${esc(pname(n.actor))}</b> `:''}${esc((NOTE_TXT[n.kind]||(()=>'ახალი შეტყობინება'))(n.ref||{}))}</span><span class="sub">${ago(n.created_at)}</span></span></button>`).join('')||empty('შეტყობინებები ჯერ არ არის');
  const unread=rows.filter(r=>!r.read).map(r=>r.id);if(unread.length){await sb.from('notifications').update({read:true}).in('id',unread);S.unreadNotes=0;renderBadges()}}catch(e){const el=$('#nb');if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
A.notifs=()=>openNotes();
A.nset=()=>{closeSheet();openPage('notifset')};
A.readall=async()=>{await sb.from('notifications').update({read:true}).eq('user_id',ME.id).eq('read',false);$$('.note.unread').forEach(e=>e.classList.remove('unread'));S.unreadNotes=0;renderBadges()};
A.note=t=>{const k=t.dataset.k,r=JSON.parse(t.dataset.r||'{}'),u=t.dataset.u;closeSheet(true);
 if((k==='room_invite'||k==='live_start')&&r.room)return openPage('room',r.room,['rooms']);if(k==='nameday'||k==='birthday')return openPage('calendar');if(k==='nameday_me'||k==='birthday_me')return openPage('namedays');if(k==='kin_req')return openPage('tree');if(k==='kin_ok')return openPage('tree',r.owner&&r.owner!==ME.id?r.owner:undefined);if(k.startsWith('help_')&&r.help)return openPage('helpreq',r.help,['help']);if(k.startsWith('bet_')&&r.fixture)return openPage('fixture',r.fixture,['sport']);if(k.startsWith('ride_')&&r.ride)return openPage('ride',r.ride,['rides']);if(k.startsWith('job_')&&r.job)return openPage('job',r.job,['jobs']);
 if(k==='repost'&&r.post)return openPage('post',r.quote&&r.by?r.by:r.post);
 if(k==='mention'&&r.post){S.openComments=!!r.comment;return openPage('post',r.post)}
 if(k==='msg_react'&&r.conv)return openChat(+r.conv);
 if(k==='story_react')return go('home');
 if((k==='event_invite'||k==='event_soon')&&r.event)return openPage('event',r.event,['events']);
 if(k.startsWith('album_')&&r.album)return openPage('album',r.album,['albums']);
 if(k==='group_pending'&&r.group){S.gmanage='pending';return openPage('group',r.group,['groups'])}
 if(k==='group_request'&&r.group){S.gmanage='requests';return openPage('group',r.group,['groups'])}
 if(k==='group_post_ok'&&r.post)return openPage('post',r.post);
 if(k.startsWith('group_')&&r.group)return openPage('group',r.group,['groups']);
 if(k==='promo'){if(r.link)openLink(r.link);return}
 if(k==='admin_coins')return openPage('coins');
 if(k==='admin_msg')return;
 if(k==='grade_plus'&&r.post)return openPage('post',r.post);
 if(k==='story_mention'&&r.story)return openStoryById(+r.story,u);
 if(k==='recipe_cook'&&r.recipe)return openPage('recipe',r.recipe,['recipes']);
 if(k==='jk_invite'&&r.table)return openPage('jktable',r.table);
 if((k==='react'||k==='comment'||k==='comment_reply'||k==='comment_like')&&r.post){S.openComments=k!=='react';openPage('post',r.post)}else if(k==='friend_req')openPage('friends');else if(k==='match'&&u)openChatWith(u);else if(k.startsWith('ad_'))openPage('pages');else if(u)openPage('user',u)};
/* a story someone marked you on: from the ring when it is there, otherwise on its own */
async function openStoryById(id,u){const i=STORIES.findIndex(g=>g.list.some(x=>x.id===id));if(i>=0){SVSRC=null;openStory(i,STORIES[i].list.findIndex(x=>x.id===id));return}
 try{const st=await q(sb.from('stories').select('id,author,media_url,media_type,created_at,audience,post_id,poll,stickers').eq('id',id).gt('expires_at',new Date().toISOString()).maybeSingle());
  if(st){await loadProfiles([st.author,...(st.stickers||[]).filter(x=>x.t==='mention').map(x=>x.u)]);openStory(0,0,[{a:st.author,list:[st]}]);return}}catch(e){}
 toast('ეს ისტორია უკვე გაქრა');if(u)openPage('user',u)}
/* new profile visitors since you last opened the list, for the header badge */
const gseenKey=()=>'gseen_'+ME.id;let GUESTS_AT=0;
async function countGuests(force){if(!ME||(!force&&Date.now()-GUESTS_AT<60000))return;GUESTS_AT=Date.now();
 const since=store.get(gseenKey(),null)||new Date(Date.now()-7*864e5).toISOString();
 try{const{count}=await sb.from('profile_visits').select('visitor',{count:'exact',head:true}).eq('visited',ME.id).gt('visited_at',since);S.newGuests=count||0;renderBadges()}catch(e){}}
function guestsSeen(){store.set(gseenKey(),new Date().toISOString());S.newGuests=0;renderBadges()}
A.guests=()=>A.ptsheet({dataset:{k:'guests'}});
async function countUnread(){countGuests();try{const{count}=await sb.from('notifications').select('id',{count:'exact',head:true}).eq('read',false).neq('kind','message');S.unreadNotes=count||0;const c=await myChats();S.unreadMsgs=c.filter(x=>!mutedNow(x)).reduce((a,x)=>a+(x.unread||0),0);renderBadges()}catch(e){}}

/* gifts, block, report */
const GIFTS=[['🌹','ვარდი',5],['☕','ყავა',3],['🍇','ყურძენი',5],['🎲','კამათელი',8],['🍷','ღვინო',10],['💐','თაიგული',15],['🧸','დათუნია',20],['🎂','ტორტი',25],['🏆','თასი',100]];
A.gift=t=>{const id=t.dataset.u;sheet(head('საჩუქარი · '+esc(pname(id)))+`<p class="hint" style="padding:12px 16px 0">ბალანსი: ${ME.coins??0} მონეტა</p><div class="gifts">${GIFTS.map(g=>`<button class="gift" data-a="sendgift" data-u="${id}" data-g="${g[0]}" aria-label="${g[1]}, ${g[2]} მონეტა">${g[0]}<small>${g[1]} · ${g[2]}</small></button>`).join('')}</div>`,'short')};
A.sendgift=async t=>{try{const bal=await rpc('send_gift',{p_to:t.dataset.u,p_emoji:t.dataset.g});setCoins(bal);closeSheet();toast(`${t.dataset.g} გაიგზავნა`);confetti()}catch(e){toast(errMsg(e));if(/not_enough/.test(e.message))openPage('coins')}};
A.umore=t=>{const id=t.dataset.u;sheet(head(esc(pname(id)))+`<div class="reasons"><button data-a="gift" data-u="${id}">საჩუქრის გაგზავნა</button><button data-a="sharepro" data-u="${id}">პროფილის გაზიარება</button><button data-a="tree" data-u="${id}">ოჯახის ხე</button>${FRIENDS.has(id)?`<button data-a="kinadd" data-u="${id}">ნათესავად მონიშვნა</button>`:''}<button data-a="report" data-type="user" data-id="${id}" data-u="${id}">საჩივარი</button><button class="warnbtn" data-a="block" data-u="${id}">დაბლოკვა</button>${isStaff()?`<button class="warnbtn" data-a="ban" data-u="${id}">მოდერაცია: შეზღუდვა</button>`:''}</div>`,'short')};
const REASONS=['სპამი ან რეკლამა','შეურაცხყოფა ან სიძულვილის ენა','შევიწროება ან მუქარა','ყალბი პროფილი','თაღლითობა','შიშველი ან სექსუალური შინაარსი','არასრულწლოვანს ეხება','ძალადობა','სხვა'];
A.report=t=>{const{type,id}=t.dataset;if(!$('#story').hidden)closeStory(true);sheet(head('საჩივარი')+`<p class="hint" style="padding:12px 16px 0">რა არის პრობლემა? ავტორი ვერ გაიგებს, ვინ გაგზავნა საჩივარი.</p><div class="reasons">${REASONS.map(r=>`<button data-a="sendrep" data-type="${type}" data-id="${esc(id)}" data-r="${r}">${r}</button>`).join('')}</div>`,'short')};
A.sendrep=async t=>{try{await q(sb.from('reports').insert({reporter:ME.id,target_type:t.dataset.type,target_id:String(t.dataset.id),reason:t.dataset.r}));closeSheet();toast('საჩივარი მიღებულია. მოდერატორი განიხილავს')}catch(e){toast(errMsg(e))}};
A.block=t=>{const id=t.dataset.u;confirmSheet('დაბლოკვა',`${esc(pname(id))} ვეღარ დაინახავს შენს პოსტებს, ვეღარ მოგწერს და ვეღარ გამოგიწვევს თამაშში. შენც აღარ დაინახავ მის შინაარსს.`,'დაბლოკვა',async()=>{await q(sb.from('blocks').insert({blocker:ME.id,blocked:id}));BLOCKED.add(id);FRIENDS.delete(id);await sb.from('friendships').delete().or(`and(requester.eq.${ME.id},addressee.eq.${id}),and(requester.eq.${id},addressee.eq.${ME.id})`);toast('დაიბლოკა');if(S.page)rp();else go(S.tab)},true)};
A.unblock=async t=>{try{await q(sb.from('blocks').delete().eq('blocker',ME.id).eq('blocked',t.dataset.u));BLOCKED.delete(t.dataset.u);toast('განიბლოკა');rp()}catch(e){toast(errMsg(e))}};

/* stories */
let STORIES=[];
async function loadStories(){const el=$('#stories');if(!el)return;try{const rows=await q(sb.from('stories').select('id,author,media_url,media_type,created_at,audience,post_id,poll,stickers').gt('expires_at',new Date().toISOString()).order('created_at').limit(200));
 const seen=new Set((await q(sb.from('story_views').select('story_id').eq('user_id',ME.id).in('story_id',rows.map(r=>r.id).slice(0,300)))).map(x=>x.story_id));
 const by=new Map();rows.forEach(r=>{if(!by.has(r.author))by.set(r.author,[]);by.get(r.author).push(r)});await loadProfiles([...by.keys(),...rows.flatMap(r=>(Array.isArray(r.stickers)?r.stickers:[]).filter(x=>x.t==='mention').map(x=>x.u))]);
 STORIES=[...by.entries()].map(([a,list])=>({a,list,seen:list.every(s=>seen.has(s.id)),close:list.some(s=>s.audience==='close')})).sort((x,y)=>(x.a===ME.id?-1:y.a===ME.id?1:0)||(x.seen-y.seen)||((FRIENDS.has(y.a)?1:0)-(FRIENDS.has(x.a)?1:0)));
 {const pg=await promoStories();if(pg.length)STORIES.splice(STORIES[0]&&STORIES[0].a===ME.id?1:0,0,...pg)}
 const mine=STORIES.find(s=>s.a===ME.id);
 let lives=[];try{lives=(await q(sb.from('rooms').select('id,host,title').eq('kind','live').eq('live',true).gt('created_at',new Date(Date.now()-12*36e5).toISOString()).order('created_at',{ascending:false}).limit(12))).filter(r=>r.host!==ME.id&&!BLOCKED.has(r.host));await loadProfiles(lives.map(r=>r.host))}catch(e){}
 el.innerHTML=`<button class="story" data-a="addstory" role="listitem"><span class="ring seen">${av('me',58)}<i>+</i></span><span>შენი ისტორია</span></button>`+lives.map(r=>`<button class="story" data-a="page" data-p="room" data-arg="${r.id}" role="listitem" aria-label="ლაივი: ${esc(r.title)}"><span class="ring live">${av(r.host,58)}<i class="lvtag">LIVE</i></span><span>${esc(String(pname(r.host)).split(' ')[0])}</span></button>`).join('')+STORIES.map((s,i)=>s.a===ME.id?'':s.promo?promoRing(s,i):`<button class="story" data-a="story" data-i="${i}" role="listitem"><span class="ring${s.seen?' seen':''}${s.close&&!s.seen?' close':''}">${av(s.a,58)}</span><span>${esc(String(pname(s.a)).split(' ')[0])}</span></button>`).join('');
 if(mine){const f=el.firstElementChild;f.dataset.a='story';f.dataset.i=STORIES.indexOf(mine);$('.ring',f).classList.toggle('seen',mine.seen)}}catch(e){el.innerHTML=`<button class="story" data-a="addstory" role="listitem"><span class="ring seen">${av('me',58)}<i>+</i></span><span>შენი ისტორია</span></button>`}}
A.addstory=async()=>{S.storyAud=S.storyAud||'all';sheet(head('ახალი ისტორია')+`<div class="seg flat" role="group" aria-label="ვინ ნახავს" style="margin:12px 16px 0"><button data-a="staud" data-v="all" aria-pressed="${S.storyAud==='all'}">ყველა</button><button data-a="staud" data-v="close" aria-pressed="${S.storyAud==='close'}">${ic('star')}ახლო მეგობრები</button></div><div class="reasons"><button data-a="storyimg">${ic('image')} ფოტო</button><button data-a="storyvid">${ic('clips')} ვიდეო (მაქს. 50 მბ)</button><button data-a="storytext">${ic('poll')} ტექსტი ან გამოკითხვა</button></div><p class="note" style="padding:0 16px 16px">ისტორია 24 საათის შემდეგ ავტომატურად ქრება.</p>`,'short')};
async function postStory(blob,type,extra){try{toast('იტვირთება…');const url=await uploadBlob(blob,type==='video'?extOf(blob):'jpg');await q(sb.from('stories').insert(Object.assign({author:ME.id,media_url:url,media_type:type,audience:S.storyAud==='close'?'close':'all'},extra||{})));closeSheet();toast('ისტორია გამოქვეყნდა');loadStories()}catch(e){toast(errMsg(e))}}
A.staud=t=>{S.storyAud=t.dataset.v;$$('[data-a="staud"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)))};
A.storyimg=async()=>{const b=await pickImage({ratios:['916','orig'],ratio:'916',max:1440,title:'ისტორიის ფოტო'});if(b)storyCompose(b,'image')};
A.storyvid=async()=>{const v=await pickVideo();if(v)storyCompose(v,'video')};
let SV=null;
A.story=t=>openStory(+t.dataset.i,0);
/* the viewer plays the story ring, or a highlight when one is given */
let SVSRC=null;const SVL=()=>SVSRC||STORIES;
function openStory(i,f,src){if(src)SVSRC=src;const s=SVL()[i];if(!s){closeStory();return}const st=s.list[f];if(!st){closeStory();return}if(SV)clearTimeout(SV.t);SV={i,f};const pr=s.promo||null,u=pr?{name:pr.brand,avatar_url:pr.brand_url,hue:330}:prof(s.a),el=$('#story'),mine=s.a===ME.id,hl=!!s.hl;
 if(pr&&!s.preview){promoSeen(pr.id);markPromoSeen(pr.id);s.seen=true}
 if(!hl&&!pr)sb.from('story_views').upsert({story_id:st.id,user_id:ME.id},{onConflict:'story_id,user_id'}).then(()=>{});
 el.innerHTML=`<div class="sv-in">${st.media_type==='video'?`<video id="svv" src="${esc(st.media_url)}" playsinline autoplay></video>`:`<img src="${esc(st.media_url)}" alt="">`}<div class="sv-shade"></div>
 <div class="sv-bars">${s.list.map((_,k)=>`<span><i class="${k<f?'done':k===f?'run':''}"${k===f&&st.media_type==='video'?' style="animation:none"':''}></i></span>`).join('')}</div>
 <div class="sv-head">${av(u,34)}<b>${esc(hl?s.title:u.name)}</b><span>${pr?'რეკლამა':hl?fdate(st.created_at):ago(st.created_at)}</span><span class="sp"></span><button class="ibtn" data-a="svpause" id="svpz" aria-label="გაჩერება">${ic('pause')}</button>${pr?'':hl?(mine?`<button class="ibtn" data-a="hlrmitem" data-id="${st.hid}" aria-label="რჩეულიდან ამოღება">${ic('trash')}</button>`:''):mine?`<button class="ibtn" data-a="storyviews" data-id="${st.id}" aria-label="ვინ ნახა">${ic('eye')}</button><button class="ibtn" data-a="sthl" data-id="${st.id}" aria-label="რჩეულებში დამატება">${ic('star')}</button><button class="ibtn" data-a="delstory" data-id="${st.id}" aria-label="წაშლა">${ic('trash')}</button>`:`<button class="ibtn" data-a="report" data-type="story" data-id="${st.id}" aria-label="საჩივარი">${ic('flag')}</button>`}<button class="ibtn" data-a="svclose" aria-label="დახურვა">${ic('x')}</button></div>
 <button class="sv-prev" data-a="svprev" aria-label="წინა"></button><button class="sv-next" data-a="svnext" aria-label="შემდეგი"></button>
 ${pr&&(pr.title||pr.body)?`<div class="sv-cap">${pr.title?`<b>${esc(pr.title)}</b>`:''}${pr.body?`<span>${esc(pr.body)}</span>`:''}</div>`:''}${pr&&pr.link?`<button class="sv-post sv-cta" data-a="promogo" data-id="${pr.id}"${s.preview?' data-prev="1"':''}>${esc(pr.cta||'გაიგე მეტი')}${ic('back')}</button>`:''}
 ${st.post_id?`<button class="sv-post" data-a="svpost" data-pid="${st.post_id}">${ic('image')}პოსტის ნახვა</button>`:''}
 ${!hl&&st.poll&&Array.isArray(st.poll.opts)?`<div class="svpoll" id="svpoll" data-id="${st.id}">${pollStoryHTML(st,null,mine)}</div>`:''}${stickersHTML(st,mine,hl)}
 ${mine||hl||pr?'':`<div class="sv-rx" role="group" aria-label="რეაქცია ისტორიაზე">${SV_RX.map(e=>`<button data-a="svreact" data-id="${st.id}" data-e="${e}" aria-label="${e}">${rg(e)}</button>`).join('')}</div><form class="sv-foot"><input class="field" id="svin" placeholder="უპასუხე…" aria-label="პასუხი ისტორიაზე" autocomplete="off"><button class="ibtn" aria-label="გაგზავნა">${ic('send')}</button></form>`}</div>`;
 if(el.hidden){el.hidden=false;navOpen('story')}const v=$('#svv');SV.left=st.poll?9000:5000;SV.why=new Set();SV.paused=false;el.classList.remove('paused','holding');
 if(v){v.onended=()=>stepStory(1);v.onloadedmetadata=()=>{const bar=$('.sv-bars i.run',el);if(bar){bar.style.animation=`fill ${v.duration||8}s linear forwards`;if(SV&&SV.paused)bar.style.animationPlayState='paused'}}}else{SV.at=Date.now();SV.t=setTimeout(()=>stepStory(1),SV.left)}
 if(st.poll&&!hl){const bar=$('.sv-bars i.run',el);if(bar&&!v)bar.style.animationDuration='9s';rpc('story_poll',{p_story:st.id}).then(r=>{const b=$('#svpoll');if(b&&+b.dataset.id===st.id&&r)b.innerHTML=pollStoryHTML(st,r,mine)}).catch(()=>{})}
 if(document.hidden)svPause('hidden');
 $$('.svask input',el).forEach(x=>{x.onfocus=()=>svPause('type');x.onblur=()=>setTimeout(()=>svResume('type'),150);x.closest('form').onsubmit=async e=>{e.preventDefault();const t=x.value.trim();if(!t)return;x.value='';x.blur();try{await storyToChat(s.a,st.id,t,'reply');toast('პასუხი გაიგზავნა, ნახავ ჩატში')}catch(y){toast(errMsg(y))}}});
 const inp=$('#svin');if(inp){inp.onfocus=()=>svPause('type');inp.onblur=()=>setTimeout(()=>svResume('type'),150);
  $('form',el).onsubmit=async e=>{e.preventDefault();const t=inp.value.trim();if(!t)return;inp.value='';inp.blur();
   try{await storyToChat(s.a,st.id,t,'reply');toast('პასუხი გაიგზავნა, ნახავ ჩატში')}catch(x){toast(errMsg(x))}}}}
/* a story can stop: hold a finger on it, type an answer, tap pause, or leave the app; it goes on from the same moment */
function svBar(){return $('#story .sv-bars i.run')}
function svPause(why){if(!SV)return;SV.why=SV.why||new Set();SV.why.add(why);if(SV.paused)return;SV.paused=true;clearTimeout(SV.t);if(SV.at)SV.left=Math.max(400,SV.left-(Date.now()-SV.at));SV.at=0;
 const v=$('#svv');if(v)try{v.pause()}catch(e){}const b=svBar();if(b)b.style.animationPlayState='paused';svPauseUI()}
function svResume(why){if(!SV||!SV.why)return;SV.why.delete(why);if(!SV.paused||SV.why.size)return;SV.paused=false;
 const v=$('#svv');if(v)v.play().catch(()=>{});else{SV.at=Date.now();clearTimeout(SV.t);SV.t=setTimeout(()=>stepStory(1),SV.left)}const b=svBar();if(b)b.style.animationPlayState='running';svPauseUI()}
function svPauseUI(){const b=$('#svpz'),el=$('#story');if(!b||!SV)return;const user=SV.why.has('user');b.innerHTML=ic(user?'play':'pause');b.setAttribute('aria-label',user?'გაგრძელება':'გაჩერება');el.classList.toggle('paused',!!SV.paused)}
A.svpause=()=>{if(!SV)return;if(SV.why&&SV.why.has('user'))svResume('user');else svPause('user')};
document.addEventListener('visibilitychange',()=>{if(!SV)return;if(document.hidden)svPause('hidden');else svResume('hidden')});
/* press and hold anywhere on the picture: the story waits and the buttons step aside */
document.addEventListener('pointerdown',e=>{if(!SV||!e.target.closest('#story .sv-prev,#story .sv-next'))return;clearTimeout(SV.ht);SV.held=false;
 SV.ht=setTimeout(()=>{if(!SV)return;SV.held=true;svPause('hold');$('#story').classList.add('holding')},220)});
['pointerup','pointercancel'].forEach(k=>document.addEventListener(k,()=>{if(!SV)return;clearTimeout(SV.ht);if(SV.held){svResume('hold');$('#story').classList.remove('holding');SV.skipTap=true;setTimeout(()=>{if(SV)SV.skipTap=false},400)}}));
/* stickers on a story: a person, a place, a countdown, a question box */
function countTxt(at){const d=new Date(at).getTime()-Date.now();if(!(d>0))return 'დადგა! 🎉';const m=Math.floor(d/6e4),dd=Math.floor(m/1440),h=Math.floor(m%1440/60),mm=m%60;
 return dd?`${dd} დღე${h?' '+h+' სთ':''}`:h?`${h} სთ${mm?' '+mm+' წთ':''}`:`${Math.max(1,mm)} წთ`}
function stickerInner(x,edit,mine){if(x.t==='mention')return `${ic('user')}<span>@${esc(String(pname(x.u)).split(' ')[0])}</span>`;
 if(x.t==='place')return `${ic('pin')}<span>${esc(x.name)}</span>`;
 if(x.t==='count')return `<b>${esc(x.title)}</b><span class="stkc" data-at="${esc(x.at)}">${countTxt(x.at)}</span>`;
 if(x.t==='ask')return `<b>${esc(x.q)}</b>${edit?'<span class="stkf">პასუხს აქ დაწერენ</span>':mine?'<small>პასუხები ჩატში მოგივა</small>':`<form class="svask"><input maxlength="300" placeholder="დაწერე პასუხი…" aria-label="პასუხი"><button aria-label="გაგზავნა">${ic('send')}</button></form>`}`;return ''}
const stkPos=x=>`left:${(+x.x||.5)*100}%;top:${(+x.y||.5)*100}%`;
function stickersHTML(st,mine,hl){const L=Array.isArray(st.stickers)?st.stickers:[];if(!L.length)return '';
 return `<div class="svst">${L.map(x=>x.t==='mention'?`<button class="sst sst-mention" data-a="svuser" data-u="${esc(x.u)}" style="${stkPos(x)}">${stickerInner(x)}</button>`:`<div class="sst sst-${esc(x.t)}" style="${stkPos(x)}">${stickerInner(x,false,mine||hl)}</div>`).join('')}</div>`}
A.svuser=t=>{const u=t.dataset.u;closeStory();openPage('user',u)};
setInterval(()=>{$$('#story .stkc').forEach(e=>{e.textContent=countTxt(e.dataset.at)})},30000);
/* the last step before a story goes out: stickers are placed on it with a finger */
function storyCompose(blob,type,extra){const C={st:[]},url=URL.createObjectURL(blob);
 layer(lhead('ისტორია')+`<div class="ph-body scmp"><div class="scbox" id="scbox">${type==='video'?`<video src="${url}" muted autoplay loop playsinline></video>`:`<img src="${url}" alt="">`}<div class="sclay" id="sclay"></div></div>
  <div class="sctools" role="group" aria-label="სტიკერები"><button type="button" data-st="mention">${ic('user')}მონიშვნა</button><button type="button" data-st="place">${ic('pin')}ადგილი</button><button type="button" data-st="count">${ic('timer')}უკუთვლა</button><button type="button" data-st="ask">${ic('help')}კითხვა</button></div>
  <div id="scp"></div><p class="note">სტიკერი თითით გადაიტანე. მოსაშორებლად დააჭირე ×-ს.</p></div>
  <div class="ph-foot"><span class="sp"></span><button class="btn" id="sc_ok">${ic('send')}გამოქვეყნება</button></div>`,()=>setTimeout(()=>URL.revokeObjectURL(url),4000));
 const lay=$('#sclay'),box=$('#scbox'),pan=$('#scp');
 const draw=()=>{lay.innerHTML=C.st.map((x,i)=>`<div class="sst sst-${x.t}" data-i="${i}" style="${stkPos(x)}">${stickerInner(x,true)}<button type="button" class="stkx" data-rm="${i}" aria-label="მოშორება">${ic('x')}</button></div>`).join('')};
 const add=x=>{if(C.st.length>=6){toast('მაქსიმუმ 6 სტიკერი');return}x.x=.5;x.y=Math.min(.82,.28+C.st.length*.12);C.st.push(x);pan.innerHTML='';draw()};
 lay.addEventListener('click',e=>{const r=e.target.closest('[data-rm]');if(r){C.st.splice(+r.dataset.rm,1);draw()}});
 lay.addEventListener('pointerdown',e=>{const k=e.target.closest('.sst');if(!k||e.target.closest('[data-rm]'))return;e.preventDefault();const i=+k.dataset.i,R=box.getBoundingClientRect();k.setPointerCapture(e.pointerId);k.classList.add('drag');
  const mv=ev=>{C.st[i].x=Math.min(.95,Math.max(.05,(ev.clientX-R.left)/R.width));C.st[i].y=Math.min(.9,Math.max(.08,(ev.clientY-R.top)/R.height));k.style.left=C.st[i].x*100+'%';k.style.top=C.st[i].y*100+'%'};
  const up=()=>{k.classList.remove('drag');k.removeEventListener('pointermove',mv);k.removeEventListener('pointerup',up);k.removeEventListener('pointercancel',up)};
  k.addEventListener('pointermove',mv);k.addEventListener('pointerup',up);k.addEventListener('pointercancel',up)});
 $$('.sctools button').forEach(b=>b.onclick=()=>{const t=b.dataset.st;
  if(t==='mention'){pan.innerHTML=`<div class="scpan"><input class="field" id="scq" placeholder="მეგობრის სახელი…" autocomplete="off"><div class="scres" id="scr"></div></div>`;const qi=$('#scq'),res=$('#scr');
   const show=()=>{const v=qi.value.trim().toLowerCase(),L=[...FRIENDS].map(prof).filter(p=>p&&p.name&&(!v||String(p.name).toLowerCase().includes(v))).slice(0,8);
    res.innerHTML=L.map(p=>`<button type="button" data-u="${p.id}">${av(p,28)}<span>${esc(p.name)}</span></button>`).join('')||'<span class="note">მეგობრებში ვერ მოიძებნა</span>';$$('button',res).forEach(x=>x.onclick=()=>add({t:'mention',u:x.dataset.u}))};qi.oninput=show;show();qi.focus()}
  else if(t==='place'){pan.innerHTML=`<form class="scpan row2"><input class="field" id="scv" maxlength="40" placeholder="მაგ. საჩხერე, ბათუმის ბულვარი" value="${esc(ME.home_place||ME.city||'')}"><button class="btn sm">დამატება</button></form>`;$('form',pan).onsubmit=e=>{e.preventDefault();const v=$('#scv').value.trim();if(v)add({t:'place',name:v})};$('#scv').focus()}
  else if(t==='count'){const d=new Date(Date.now()+7*864e5);d.setMinutes(0,0,0);const loc=new Date(d.getTime()-d.getTimezoneOffset()*6e4).toISOString().slice(0,16);
   pan.innerHTML=`<form class="scpan"><input class="field" id="sct" maxlength="40" placeholder="მაგ. ჩვენი ქორწილი"><div class="row2"><input class="field" id="scd" type="datetime-local" value="${loc}"><button class="btn sm">დამატება</button></div></form>`;
   $('form',pan).onsubmit=e=>{e.preventDefault();const ti=$('#sct').value.trim(),dv=$('#scd').value;if(!ti){toast('დაწერე, რას ითვლი');return}const at=new Date(dv);if(!(at>new Date())){toast('აირჩიე მომავალი დრო');return}add({t:'count',title:ti,at:at.toISOString()})};$('#sct').focus()}
  else if(t==='ask'){pan.innerHTML=`<form class="scpan row2"><input class="field" id="sca" maxlength="60" value="მკითხე რამე"><button class="btn sm">დამატება</button></form>`;$('form',pan).onsubmit=e=>{e.preventDefault();add({t:'ask',q:$('#sca').value.trim()||'მკითხე რამე'})};$('#sca').select()}});
 $('#sc_ok').onclick=async()=>{const b=$('#sc_ok');b.disabled=true;const ex=Object.assign({},extra||{});if(C.st.length)ex.stickers=C.st;await postStory(blob,type,ex);closeLayer()}}
/* an answer or an emoji goes to the author's chat together with the story's picture */
async function storyToChat(author,storyId,body,act){const c=await rpc('start_dm',{other:author});await q(sb.from('messages').insert({conv_id:c,sender:ME.id,body,kind:'text',media:{story:storyId,act}}));return c}
function stepStory(d){if(!SV)return;const L=SVL();let i=SV.i,f=SV.f+d;if(f>=L[i].list.length){i++;f=0}else if(f<0){i--;if(i<0){i=0;f=0}else f=L[i].list.length-1}openStory(i,f)}
function closeStory(nav){if(!nav)navKill('story');SVSRC=null;if(SV){clearTimeout(SV.t);clearTimeout(SV.ht)}SV=null;const el=$('#story');el.hidden=true;el.innerHTML='';el.classList.remove('paused','holding');if($('#stories'))loadStories()}
/* polls and quick reactions on stories */
const SV_RX=['❤️','😂','😮','😢','🔥','👏','🍷'];
function pollStoryHTML(st,r,mine){const p=st.poll,voted=r&&r.mine!=null,show=mine||voted,tot=r?.total||0;
 return `<b>${esc(p.q||'გამოკითხვა')}</b>${p.opts.map((o,i)=>{const n=r?.counts?.[i]||0,pc=tot?Math.round(n/tot*100):0;return show?`<div class="svpo${r?.mine===i?' mine':''}" style="--pc:${pc}%"><span>${esc(o)}</span><em>${pc}%</em></div>`:`<button class="svpo" data-a="svvote" data-id="${st.id}" data-i="${i}">${esc(o)}</button>`}).join('')}${show?`<small>${tot} ხმა</small>`:''}`}
A.svvote=async t=>{const id=+t.dataset.id,i=+t.dataset.i,b=$('#svpoll');if(SV)clearTimeout(SV.t);$$('#svpoll button').forEach(x=>x.disabled=true);
 try{await q(sb.from('story_votes').insert({story_id:id,user_id:ME.id,opt:i}));const r=await rpc('story_poll',{p_story:id});const s0=SVL()[SV?.i]?.list[SV?.f];if(b&&s0)b.innerHTML=pollStoryHTML(s0,r,false)}catch(e){toast(/duplicate/i.test(e.message||'')?'უკვე მიეცი ხმა':errMsg(e))}
 if(SV)SV.t=setTimeout(()=>stepStory(1),2500)};
const SV_SENT=new Set();
A.svreact=async t=>{const id=+t.dataset.id,e=t.dataset.e,a=SV&&SVL()[SV.i]?.a;pop(t);burst(t);if(SV_SENT.has(id+e)){toast(`${e} უკვე გაგზავნილია`);return}SV_SENT.add(id+e);
 try{await q(sb.from('story_reactions').upsert({story_id:id,user_id:ME.id,emoji:e},{onConflict:'story_id,user_id'}));if(a)await storyToChat(a,id,e,'react');toast(`${e} გაეგზავნა, ნახავ ჩატში`)}catch(x){SV_SENT.delete(id+e);toast(errMsg(x))}};
A.svpost=t=>{const id=+t.dataset.pid;closeStory();openPage('post',id)};
A.svclose=()=>closeStory();A.svnext=()=>{if(SV&&SV.skipTap)return;stepStory(1)};A.svprev=()=>{if(SV&&SV.skipTap)return;stepStory(-1)};
A.delstory=async t=>{try{await q(sb.from('stories').delete().eq('id',+t.dataset.id));toast('ისტორია წაიშალა');closeStory()}catch(e){toast(errMsg(e))}};
A.storyviews=async t=>{clearTimeout(SV?.t);const sid=+t.dataset.id,st=SVL()[SV?.i]?.list.find(x=>x.id===sid);
 try{const[rows,rx,votes,poll]=await Promise.all([q(sb.from('story_views').select('user_id,seen_at').eq('story_id',sid)),q(sb.from('story_reactions').select('user_id,emoji').eq('story_id',sid)),q(sb.from('story_votes').select('user_id,opt').eq('story_id',sid)),st?.poll?rpc('story_poll',{p_story:sid}):null]);
  const R=new Map(rx.map(r=>[r.user_id,r.emoji])),V=new Map(votes.map(v=>[v.user_id,v.opt])),ids=[...new Set([...rows.map(r=>r.user_id),...R.keys(),...V.keys()])].filter(u=>u!==ME.id);await loadProfiles(ids);closeStory();
  sheet(head(`ნახვები · ${ids.length}`)+`<div class="ph-body">${st?.poll&&poll?`<div class="svpoll inline">${pollStoryHTML(st,poll,true)}</div>`:''}${R.size?`<p class="note">${R.size} რეაქცია</p>`:''}<div class="list">${ids.sort((a,b)=>(R.has(b)?1:0)-(R.has(a)?1:0)).map(u=>`<button class="row" data-a="user" data-u="${u}">${av(u,42)}<span class="grow"><b>${esc(pname(u))}${vb(u)}</b>${V.has(u)&&st?.poll?`<span class="sub">ხმა: ${esc(st.poll.opts[V.get(u)]||'')}</span>`:''}</span>${R.has(u)?`<span class="rxe">${rg(R.get(u))}</span>`:''}</button>`).join('')||'<p class="muted">ჯერ არავის უნახავს</p>'}</div></div>`)}catch(e){toast(errMsg(e))}};

/* clips: a vertical feed, one clip to a screen; the one on screen plays by itself, a tap pauses it, two taps like it */
const CLIP={io:null,cur:null,raf:0};
R.clips=()=>{view.innerHTML=`<div class="clip-top"><span class="on">კლიპები</span><button class="cliptop-add" data-a="newclip" aria-label="კლიპის ატვირთვა">${ic('plus')}</button></div><div id="clipb"><section class="clip clipload"><span class="spin"></span></section></div>`;
 fetchPosts(b=>b.eq('is_clip',true).eq('hidden',false).order('created_at',{ascending:false}).limit(30)).then(rows=>{const el=$('#clipb');if(!el)return;rows=rows.filter(p=>(p.media||[]).some(m=>m.type==='video'));
  if(!rows.length){el.innerHTML=`<section class="clip clipempty"><div><h3>კლიპები ჯერ არ არის</h3><p>ატვირთე პირველი მოკლე ვიდეო და აქ გამოჩნდება.</p><button class="btn" data-a="newclip">${ic('plus')}კლიპის ატვირთვა</button></div></section>`;return}
  el.innerHTML=rows.map(clipHTML).join('');clipWire(el)}).catch(e=>{const el=$('#clipb');if(el)el.innerHTML=`<section class="clip clipempty"><div><h3>ვერ ჩაიტვირთა</h3><p>${errMsg(e)}</p></div></section>`})};
function clipHTML(p){const v=p.media.find(m=>m.type==='video'),s=STAT.get(p.id)||blankStat(p.id),u=p.ap||prof(p.author),on=s.my_reaction==='❤️',snd=!!S.clipSound,eco=ECO();
 return `<section class="clip${eco?' paused':''}" data-pid="${p.id}"><video class="cv" src="${esc(v.url)}"${mPoster(v)?` poster="${esc(mPoster(v))}"`:''} playsinline loop muted preload="none" disablepictureinpicture disableremoteplayback></video>
  <button class="ctap" data-a="ctap" aria-label="${eco?'ჩართვა':'პაუზა'}"></button><div class="shade"></div>
  <span class="cbig" aria-hidden="true">${ic('play','currentColor')}${eco?'<small>შეხებით ჩართვა</small>':''}</span><span class="cbuf" aria-hidden="true"><span class="spin"></span></span><span class="burst">${ic('heart','currentColor')}</span>
  <div class="cerr" hidden>${ic('clips')}<b>ეს ვიდეო ვერ ჩაირთო</b><small>შესაძლოა მის ფორმატს ეს ბრაუზერი ვერ კითხულობს</small></div>
  <div class="side"><button data-a="user" data-u="${u.id}" class="cav" aria-label="${esc(u.name)}">${av(u,46)}</button>
  <button class="${on?'on':''}" data-a="clike" data-pid="${p.id}" aria-label="მოწონება">${ic('heart',on?'currentColor':'')}<span>${fmt(rTotal(s))}</span></button>
  <button data-a="comments" data-pid="${p.id}" aria-label="კომენტარები">${ic('comment')}<span>${fmt(s.comments)}</span></button>
  <button data-a="share" data-pid="${p.id}" aria-label="გაზიარება">${ic('send')}<span>გაზიარება</span></button><button data-a="pmore" data-pid="${p.id}" aria-label="მეტი">${ic('more')}</button></div>
  <div class="cap"><b>${esc(u.name)}${vb(u)}</b>${tx(p.body,'media')}</div><button class="mute" data-a="unmute" aria-pressed="${snd}" aria-label="${snd?'ხმის გამორთვა':'ხმის ჩართვა'}">${ic(snd?'vol':'voloff')}</button><div class="cprog" aria-hidden="true"><i></i></div></section>`}
function clipWire(el){if(CLIP.io)CLIP.io.disconnect();CLIP.cur=null;
 CLIP.io=new IntersectionObserver(es=>es.forEach(e=>{const c=e.target;if(e.isIntersecting&&e.intersectionRatio>.6)clipOn(c);else if(CLIP.cur===c)clipOff(c)}),{root:view,threshold:[0,.6,1]});
 $$('.clip[data-pid]',el).forEach(c=>{const v=$('video',c),ok=()=>{clearTimeout(c._bt);c.classList.remove('buf')};
  v.addEventListener('loadedmetadata',()=>c.classList.toggle('land',v.videoWidth>v.videoHeight*1.05));
  v.addEventListener('waiting',()=>{clearTimeout(c._bt);c._bt=setTimeout(()=>{if(!v.paused)c.classList.add('buf')},350)});
  v.addEventListener('playing',()=>{ok();c.classList.add('started');clipProg()});v.addEventListener('canplay',ok);v.addEventListener('pause',ok);
  v.addEventListener('error',()=>{ok();c.classList.add('bad');c.classList.remove('paused');const m=$('.cerr',c);if(m)m.hidden=false});
  CLIP.io.observe(c)})}
function clipOn(c){if(CLIP.cur&&CLIP.cur!==c)clipOff(CLIP.cur);CLIP.cur=c;const v=$('video',c);if(!v)return;
 /* this one and the next start loading, so a swipe lands on a clip that is ready */
 if(!ECO()){if(v.preload==='none')v.preload='auto';const n=c.nextElementSibling&&$('video',c.nextElementSibling);if(n&&n.preload==='none')n.preload='auto'}
 if(ECO()&&!c._go)return;if(c._held)return;clipPlay(c)}
function clipOff(c){const v=$('video',c);if(v){v.pause();try{if(v.currentTime>0)v.currentTime=0}catch(e){}}if(CLIP.cur===c)CLIP.cur=null;c._held=0;if(!ECO())c.classList.remove('paused');const b=$('.cprog i',c);if(b)b.style.transform=''}
function clipPlay(c){const v=$('video',c);if(!v||c.classList.contains('bad'))return;v.muted=!S.clipSound;clipSnd(c);c.classList.remove('paused');$('.ctap',c)?.setAttribute('aria-label','პაუზა');
 const r=v.play();if(r&&r.catch)r.catch(e=>{if(!c.isConnected||CLIP.cur!==c||!e||e.name!=='NotAllowedError')return;
  /* the browser would not start it with sound: it starts muted, the sound button stays one tap away */
  if(!v.muted){v.muted=true;S.clipSound=false;$$('.clip',view).forEach(clipSnd);v.play().catch(()=>c.classList.add('paused'))}else c.classList.add('paused')});clipProg()}
function clipProg(){if(CLIP.raf)return;const f=()=>{const c=CLIP.cur,v=c&&$('video',c);if(!v||!c.isConnected||v.paused){CLIP.raf=0;return}const b=$('.cprog i',c);if(b&&v.duration)b.style.transform=`scaleX(${Math.min(1,v.currentTime/v.duration)})`;CLIP.raf=requestAnimationFrame(f)};CLIP.raf=requestAnimationFrame(f)}
function clipSnd(c){const b=$('.mute',c);if(!b)return;const on=!!S.clipSound;b.innerHTML=ic(on?'vol':'voloff');b.setAttribute('aria-pressed',String(on));b.setAttribute('aria-label',on?'ხმის გამორთვა':'ხმის ჩართვა')}
A.ctap=t=>{const c=t.closest('.clip'),v=c&&$('video',c);if(!v)return;const now=Date.now(),T=A.ctap;
 if(T.c===c&&now-(T.l||0)<300){clearTimeout(T.t);T.l=0;const b=$('.burst',c);if(b){b.classList.remove('go');void b.offsetWidth;b.classList.add('go')}const s=STAT.get(+c.dataset.pid);if(!s||s.my_reaction!=='❤️'){const h=$('[data-a="clike"]',c);if(h)A.clike(h)}return}
 T.c=c;T.l=now;clearTimeout(T.t);T.t=setTimeout(()=>{T.l=0;if(!c.isConnected)return;if(v.paused){c._held=0;c._go=1;if(CLIP.cur&&CLIP.cur!==c)clipOff(CLIP.cur);CLIP.cur=c;clipPlay(c)}else{v.pause();c._held=1;c.classList.add('paused');t.setAttribute('aria-label','ჩართვა')}},260)};
document.addEventListener('visibilitychange',()=>{const c=CLIP.cur;if(!c||!c.isConnected)return;const v=$('video',c);if(!v)return;if(document.hidden)v.pause();else if(!c._held&&!(ECO()&&!c._go))clipPlay(c)});
A.clike=async t=>{const id=pidOf(t),s=STAT.get(id)||blankStat(id),on=s.my_reaction==='❤️';await setReaction(id,on?null:'❤️');const now=STAT.get(id);t.classList.toggle('on',!on);t.innerHTML=`${ic('heart',!on?'currentColor':'')}<span>${fmt(rTotal(now))}</span>`;if(!on){pop($('svg',t));burst(t,'#FF5A6E')}};
A.unmute=t=>{const c=t.closest('.clip'),v=c&&$('video',c);if(!v)return;S.clipSound=!S.clipSound;v.muted=!S.clipSound;$$('.clip',view).forEach(clipSnd);if(!v.muted&&v.paused&&CLIP.cur===c&&!c._held&&!(ECO()&&!c._go))clipPlay(c)};
A.newclip=()=>compose({clip:true});

/* close friends for stories */
PG.close={r(){view.innerHTML=pgHead('ახლო მეგობრები')+`<p class="hint" style="padding:12px 16px 0">„ახლო მეგობრებისთვის“ გამოქვეყნებულ ისტორიას მხოლოდ ესენი ნახავენ. მათ არ ეცნობებათ, რომ სიაში არიან.</p><div id="clb">${skel(3)}</div>`;loadClose()}};
async function loadClose(){const el=$('#clb');if(!el)return;try{await loadFriends();const rows=await q(sb.from('close_friends').select('friend').eq('owner',ME.id));const on=new Set(rows.map(r=>r.friend));if(!el.isConnected)return;
 el.innerHTML=FRIENDS.size?`<div class="list">${[...FRIENDS].map(id=>`<label class="row pick">${av(id,44)}<span class="grow"><b>${esc(pname(id))}</b></span><input type="checkbox" data-cf="${id}"${on.has(id)?' checked':''} aria-label="ახლო მეგობარი"></label>`).join('')}</div>`:empty('მეგობრები ჯერ არ გყავს','',`<button class="btn" data-a="page" data-p="friends">მეგობრების პოვნა</button>`);
 $$('[data-cf]',el).forEach(i=>i.onchange=async()=>{const f=i.dataset.cf;try{if(i.checked)await q(sb.from('close_friends').insert({owner:ME.id,friend:f}));else await q(sb.from('close_friends').delete().eq('owner',ME.id).eq('friend',f));toast(i.checked?'დაემატა ახლო მეგობრებში':'ამოიშალა')}catch(e){toast(errMsg(e));i.checked=!i.checked}})}
 catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}


/* a story made of text on a colour, optionally with a poll (2 to 4 answers) */
const STG=[['#A8164A','#5B0B2A'],['#2C7A55','#0F3D2A'],['#C98A12','#7A4A05'],['#3E5BD8','#1B2A70'],['#7A3FC2','#341565'],['#1D1724','#4A3A56']];
A.storytext=()=>{const T={g:0,poll:false,opts:['კი','არა']};
 layer(lhead('ტექსტი ან გამოკითხვა')+`<div class="ph-body stc"><div class="stprev" id="stp"><span id="stpt">დაწერე რამე…</span></div>
  <textarea class="field" id="st_t" rows="3" maxlength="200" placeholder="ტექსტი ისტორიისთვის" aria-label="ტექსტი"></textarea>
  <div class="stgs" role="group" aria-label="ფერი">${STG.map((g,i)=>`<button type="button" data-g="${i}" style="--a:${g[0]};--b:${g[1]}" aria-label="ფერი ${i+1}" aria-pressed="${!i}"></button>`).join('')}</div>
  <label class="chk"><input type="checkbox" id="st_p"><span>გამოკითხვის დამატება</span></label><div id="st_pf" hidden></div></div>
  <div class="ph-foot"><span class="sp"></span><button class="btn" id="st_ok">შემდეგი</button></div>`);
 const ta=$('#st_t'),pv=$('#stp'),pt=$('#stpt');
 const paint=()=>{const g=STG[T.g];pv.style.background=`linear-gradient(160deg,${g[0]},${g[1]})`;pt.textContent=ta.value.trim()||(T.poll?'':'დაწერე რამე…')};
 const pollUI=()=>{const f=$('#st_pf');f.hidden=!T.poll;if(!T.poll){f.innerHTML='';paint();return}
  f.innerHTML=`<input class="field sq" id="st_q" maxlength="90" placeholder="კითხვა (მაგ. ხინკალი თუ მწვადი?)">${T.opts.map((o,i)=>`<div class="prow"><input class="field sq" data-o="${i}" maxlength="30" value="${esc(o)}" placeholder="პასუხი ${i+1}">${i>1?`<button type="button" class="ibtn sm" data-or="${i}" aria-label="წაშლა">${ic('x')}</button>`:''}</div>`).join('')}${T.opts.length<4?'<button type="button" class="btn sm ghost" id="st_add">პასუხის დამატება</button>':''}`;
  $$('[data-o]',f).forEach(i=>i.oninput=()=>{T.opts[+i.dataset.o]=i.value});$$('[data-or]',f).forEach(b=>b.onclick=()=>{T.opts.splice(+b.dataset.or,1);pollUI()});const ad=$('#st_add');if(ad)ad.onclick=()=>{T.opts.push('');pollUI()};paint()};
 ta.oninput=paint;$$('.stgs button').forEach(b=>b.onclick=()=>{T.g=+b.dataset.g;$$('.stgs button').forEach(x=>x.setAttribute('aria-pressed',String(x===b)));paint()});
 $('#st_p').onchange=e=>{T.poll=e.target.checked;pollUI()};paint();setTimeout(()=>ta.focus(),150);
 $('#st_ok').onclick=async()=>{const text=ta.value.trim();let poll=null;
  if(T.poll){const qv=($('#st_q')?.value||'').trim(),opts=T.opts.map(x=>x.trim()).filter(Boolean);if(opts.length<2){toast('გამოკითხვას მინიმუმ 2 პასუხი სჭირდება');return}poll={q:qv,opts}}
  if(!text&&!poll){toast('დაწერე ტექსტი ან დაამატე გამოკითხვა');return}
  const b=$('#st_ok');b.disabled=true;try{const blob=await textStoryImage(text,STG[T.g],!!poll);closeLayer();storyCompose(blob,'image',poll?{poll}:null)}catch(e){toast(errMsg(e));b.disabled=false}}};
async function textStoryImage(text,g,withPoll){const W=1080,H=1920,c=document.createElement('canvas');c.width=W;c.height=H;const x=c.getContext('2d');
 const font=getComputedStyle(document.body).fontFamily||'sans-serif';try{await document.fonts?.ready}catch(e){}
 const gr=x.createLinearGradient(0,0,W*.4,H);gr.addColorStop(0,g[0]);gr.addColorStop(1,g[1]);x.fillStyle=gr;x.fillRect(0,0,W,H);
 x.globalAlpha=.08;x.fillStyle='#fff';for(let i=0;i<6;i++){x.beginPath();x.arc(W*(i%2?.85:.12),H*(.15+i*.15),120+i*30,0,Math.PI*2);x.fill()}x.globalAlpha=1;
 if(text){let size=text.length>120?58:text.length>60?70:88;x.font=`700 ${size}px ${font}`;const words=text.replace(/\s+/g,' ').split(' '),lines=[];let line='';
  for(const w of words){const t=line?line+' '+w:w;if(x.measureText(t).width>W-160&&line){lines.push(line);line=w}else line=t}if(line)lines.push(line);
  const lh=size*1.3,top=(withPoll?H*.3:H/2)-lines.length*lh/2;x.fillStyle='#fff';x.textAlign='center';x.textBaseline='middle';x.shadowColor='rgba(0,0,0,.25)';x.shadowBlur=18;
  lines.slice(0,12).forEach((l,i)=>x.fillText(l,W/2,top+i*lh+lh/2))}
 return new Promise((res,rej)=>c.toBlob(b=>b?res(b):rej(new Error('სურათი ვერ შეიქმნა')),'image/jpeg',.9))}
