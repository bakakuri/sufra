/* first steps for new people: a photo, school or university (into the class and course groups at once), city and home region, five people, a first post */
const fsKey=k=>`fs:${ME.id}:${k}`;
/* "from Tbilisi" in Georgian: თბილისი → თბილისიდან, მცხეთა → მცხეთიდან, Berlin → ბერლინიდან */
const ablative=w=>{w=String(w||'').trim();if(!w)return '';const l=w.slice(-1);return /ი$/.test(w)?w+'დან':l==='ა'?w.slice(0,-1)+'იდან':/[ეოუ]$/.test(w)?w+'დან':w+'იდან'};
const FS_IDEAS=()=>{const c=String(ME.city||'').trim(),r=String(ME.home_region||'').trim();return ['გამარჯობა, კურსელებო! 👋',c?`მოგესალმებით ${ablative(c)}! 👋`:'ახალი ვარ აქ, გავიცნოთ ერთმანეთი',r&&r!==c?`ვინ არის აქ ${ablative(r)}?`:'რომელი ქართული კერძი გიყვართ ყველაზე მეტად?']};
async function fsProgress(){const out={photo:!!ME.avatar_url,edu:false,place:!!(String(ME.city||'').trim()&&(ME.home_region||ME.home_place||ME.abroad)),people:0,post:false};
 try{const[f,p]=await Promise.all([
   sb.from('friendships').select('requester',{count:'exact',head:true}).or(`requester.eq.${ME.id},and(addressee.eq.${ME.id},status.eq.accepted)`),
   sb.from('posts').select('id',{count:'exact',head:true}).eq('author',ME.id).eq('draft',false)]);
  out.people=f.count||0;out.post=(p.count||0)>0}catch(e){}
 try{if(typeof kuEduOf==='function')out.edu=(await kuEduOf(ME.id)).length>0}catch(e){}
 out.done=[out.photo,out.edu,out.place,out.people>=5,out.post].filter(Boolean).length;return out}

/* the card on the home feed, until the four steps are done or it is hidden */
async function loadFirstSteps(){const el=$('#fsteps');if(!el||!ME||store.get(fsKey('hide'),0))return;const p=await fsProgress();const box=$('#fsteps');if(!box)return;
 if(p.done>=5){if(!store.get(fsKey('cheer'),0)&&store.get(fsKey('seen'),0)){store.set(fsKey('cheer'),1);box.innerHTML=`<section class="fsc done"><span class="fsic">${ic('check')}</span><div class="grow"><b>ყოჩაღ! პირველი ნაბიჯები გადადგმულია</b><span class="sub">Peera უკვე შენია.</span></div><button class="ibtn sm" data-a="fshide" aria-label="დახურვა">${ic('x')}</button></section>`}else box.innerHTML='';return}
 store.set(fsKey('seen'),1);
 const items=[['photo','camera','პროფილის ფოტო',p.photo,''],['edu','school','სკოლა ან უნივერსიტეტი',p.edu,''],['place','pin','ქალაქი და კუთხე',p.place,''],['people','users','დაამატე 5 ადამიანი',p.people>=5,`${Math.min(p.people,5)}/5`],['post','edit','პირველი პოსტი',p.post,'']];
 box.innerHTML=`<section class="fsc"><div class="fshead"><div class="grow"><b>პირველი ნაბიჯები</b><span class="sub">${p.done} / 5 შესრულებულია</span></div><button class="ibtn sm" data-a="fshide" aria-label="დამალვა">${ic('x')}</button></div>
  <div class="fsbar" role="progressbar" aria-valuemin="0" aria-valuemax="5" aria-valuenow="${p.done}"><i style="width:${p.done*20}%"></i></div>
  <div class="fslist">${items.map(([,i,l,ok,n],ix)=>`<button class="fsi${ok?' ok':''}" data-a="fsgo" data-s="${ix}"${ok?' aria-disabled="true"':''}><span class="fsic">${ic(ok?'check':i)}</span><span class="grow">${l}${n&&!ok?` <em>${n}</em>`:''}</span>${ok?'':`<span class="fsgo">${ic('back')}</span>`}</button>`).join('')}</div></section>`}
A.fshide=()=>{store.set(fsKey('hide'),1);const el=$('#fsteps');if(el)el.innerHTML=''};
A.fsgo=t=>{if(t.getAttribute('aria-disabled')==='true')return;firstSteps(+t.dataset.s)};

/* the wizard: one step per screen, every step can be skipped */
let FSW=null;
async function firstSteps(step=0){const w=FSW={step,p:null};w.p=await fsProgress();if(FSW===w)drawFS()}
function drawFS(){const w=FSW;if(!w)return;const i=w.step;
 const dots=`<div class="fsdots" aria-hidden="true">${[0,1,2,3,4].map(k=>`<i class="${k<i?'done':k===i?'on':''}"></i>`).join('')}</div>`;
 let body='',main='';
 if(i===0){body=`<div class="fsstep"><button class="fsav" data-a="fsphoto" aria-label="ფოტოს არჩევა">${ME.avatar_url?av('me',120):`<span class="fsph">${ic('camera')}</span>`}<i>${ic('camera')}</i></button><h3>${ME.avatar_url?'კარგი ფოტოა!':'დაამატე პროფილის ფოტო'}</h3><p class="muted">ფოტოთი მეგობრები და ნაცნობები უფრო ადვილად გიცნობენ.</p></div>`;
  main=ME.avatar_url?`<button class="btn" data-a="fsnext">შემდეგი</button>`:`<button class="btn" data-a="fsphoto">ფოტოს არჩევა</button>`}
 else if(i===1){body=`<div class="fsstep left"><h3>სად სწავლობ ან სწავლობდი?</h3><p class="muted">შეგიყვანთ შენი კლასისა და კურსის ჯგუფებში, სადაც კლასელები და კურსელები დაგხვდებიან.</p><form class="fsedu" id="eduf"></form></div>`;
  main=`<button class="btn" data-a="fsedu">შენახვა</button>`}
 else if(i===2){body=`<div class="fsstep left"><h3>საიდან ხარ?</h3><p class="muted">ქალაქით და კუთხით მოგძებნიან თანასოფლელები, „ჯგუფებში“ კი შენი კუთხის ჯგუფებს ნახავ.</p>
  <label class="fld">სად ცხოვრობ<input id="fs_c" list="fscities" maxlength="60" value="${esc(ME.city||'')}" placeholder="მაგ. თბილისი"></label><datalist id="fscities">${CITIES.map(c=>`<option value="${c}">`).join('')}</datalist>
  <label class="fld">მშობლიური კუთხე<select id="fs_r"><option value="">აირჩიე</option>${REGIONS.map(r=>`<option${ME.home_region===r?' selected':''}>${r}</option>`).join('')}</select></label>
  <label class="fld">სოფელი ან ქალაქი (არასავალდებულო)<input id="fs_p" maxlength="60" value="${esc(ME.home_place||'')}" placeholder="მაგ. სვირი, ონი, ზესტაფონი"></label></div>`;
  main=`<button class="btn" data-a="fsplace">შენახვა</button>`}
 else if(i===3){body=`<div class="fsstep left"><div class="fsrow"><div class="grow"><h3>დაამატე 5 ადამიანი</h3><p class="muted">მეგობრები, ნათესავები, თანასოფლელები. მათი პოსტები შენს ფიდში გამოჩნდება.</p></div><div class="fscount" aria-live="polite"><b id="fs_n">${Math.min(w.p?.people||0,5)}</b><span>/5</span></div></div><div class="list" id="fs_l">${skel(3)}</div></div>`;
  main=`<button class="btn" data-a="fsnext">შემდეგი</button>`}
 else{body=`<div class="fsstep"><span class="fsph">${ic('edit')}</span><h3>დაწერე პირველი პოსტი</h3><p class="muted">მიესალმე კურსელებს ან გაუზიარე ფოტო. აირჩიე იდეა ან დაწერე შენი.</p><div class="fsideas">${FS_IDEAS().map((x,k)=>`<button class="tchip" data-a="fspost" data-k="${k}">${esc(x)}</button>`).join('')}</div></div>`;
  main=`<button class="btn" data-a="fspost">პოსტის დაწერა</button>`}
 w.redraw=true;
 sheet(head('პირველი ნაბიჯები')+dots+`<div class="ph-body fsbody">${body}</div><div class="ph-foot"><button class="btn ghost" data-a="fsnext">${i===4?'მოგვიანებით':'გამოტოვება'}</button><span class="sp"></span>${main}</div>`,'fspanel',()=>{if(FSW===w&&!w.redraw){FSW=null;loadFirstSteps()}});
 w.redraw=false;if(i===3)fsPeople();if(i===1&&typeof eduDraw==='function'){w.edu=w.edu||eduNew();eduDraw(w.edu);const f=$('#eduf');if(f)f.onsubmit=ev=>{ev.preventDefault();A.fsedu($('.fspanel [data-a="fsedu"]')||document.createElement('button'))}}}
function fsNext(){const w=FSW;if(!w)return;if(w.step>=4){FSW=null;closeSheet();loadFirstSteps();return}w.step++;drawFS()}
A.fsnext=()=>fsNext();
A.fsedu=async t=>{const w=FSW;if(!w||!w.edu)return;const o=eduBuild(w.edu);if(typeof o==='string'){toast(o);return}t.disabled=true;
 try{const E=(await kuEduOf(ME.id)).filter(x=>x.key!==o.key);E.push(o);const db=await kuEduSave(E);KUR.cache.edu=E;w.p.edu=true;
  if(db){let n=0;try{const ids=await q(sb.rpc('join_edu_groups'));n=(ids||[]).length;KUR.groups=null}catch(e){}toast(n?`შეგიყვანეთ ${n} ჯგუფში: იქ შენი კლასელები და კურსელები იქნებიან`:'შენახულია')}else toast('შენახულია');fsNext()}catch(e){toast(errMsg(e));t.disabled=false}};
A.fsphoto=async()=>{const before=ME.avatar_url;await setMyPic('avatar');if(!FSW)return;if(ME.avatar_url&&ME.avatar_url!==before){FSW.p.photo=true;fsNext()}else drawFS()};
A.fsplace=async t=>{const c=$('#fs_c').value.trim(),r=$('#fs_r').value,pl=$('#fs_p').value.trim();if(!c&&!r&&!pl){fsNext();return}t.disabled=true;
 const upd={city:c,home_region:r||null,home_place:pl||null};
 try{await q(sb.from('profiles').update(upd).eq('id',ME.id));Object.assign(ME,upd);renderSide();fsNext()}catch(e){toast(errMsg(e));t.disabled=false}};
async function fsPeople(){const el=$('#fs_l');if(!el)return;let s=[],inv=null;try{s=await rpc('friend_suggestions',{p_limit:15})}catch(e){}
 /* the friend whose link brought me comes first */
 try{const r=await q(sb.from('referrals').select('inviter').eq('user_id',ME.id).maybeSingle());if(r&&r.inviter&&!FRIENDS.has(r.inviter)){const pr=await q(sb.from('profiles').select(PCOLS).eq('id',r.inviter).maybeSingle());if(pr){inv=pr.id;s=[pr,...s.filter(x=>x.id!==pr.id)]}}}catch(e){}
 if(s.length<6){try{const more=await q(sb.from('profiles').select(PCOLS).eq('onboarded',true).neq('id',ME.id).order('last_seen',{ascending:false,nullsFirst:false}).limit(20));more.forEach(p=>{if(p.id!==ME.id&&!s.some(x=>x.id===p.id)&&!FRIENDS.has(p.id)&&!BLOCKED.has(p.id))s.push(p)})}catch(e){}}
 s=await reachOnly(s.filter(p=>p.id!==ME.id));s.forEach(p=>PC.set(p.id,Object.assign(PC.get(p.id)||{},p)));const box=$('#fs_l');if(!box)return;
 box.innerHTML=(s.slice(0,15).map(p=>`<div class="row fsp">${av(p,44)}<span class="grow"><b>${esc(p.name)}${vb(p)}</b><span class="sub">${p.id===inv?'შენ მოგიწვია':p.mutual?p.mutual+' საერთო მეგობარი':esc([p.city,p.home_region].filter(Boolean).join(' · ')||'Peera-ზეა')}</span></span>${FRIENDS.has(p.id)||PENDING_OUT.has(p.id)?'<span class="ptag">გაგზავნილია</span>':`<button class="btn sm" data-a="fsadd" data-u="${p.id}">დამატება</button>`}</div>`).join('')||empty('ჯერ ვერავინ ვიპოვეთ','მოგვიანებით სცადე ან მოიწვიე მეგობრები.','<button class="btn ghost" data-a="fsinv">მეგობრის მოწვევა</button>'))+(s.length&&s.length<8?`<div class="fsinv"><p class="muted">აქ ჯერ ცოტანი ვართ. მოიწვიე შენი მეგობრები და კლასელები${INVR.r&&INVR.r.invite?`: თითოეულზე ${INVR.r.invite} მონეტა`:''}.</p><button class="btn ghost" data-a="fsinv">${ic('share')}მოწვევის ბმული</button></div>`:'')}
/* in the wizard the link is shared at once (another sheet would close the wizard) */
A.fsinv=async()=>{const R=typeof invRules==='function'?await invRules():{};shareLink(invUrl(),R.welcome?`შემოდი Peera-ზე: ჩემი ბმულით რეგისტრაციისას ${R.welcome} მონეტა საჩუქრად`:'შემოდი Peera-ზე')};
A.fsadd=async t=>{const id=t.dataset.u;t.disabled=true;try{if(PENDING_IN.has(id)){await q(sb.from('friendships').update({status:'accepted'}).eq('requester',id).eq('addressee',ME.id));PENDING_IN.delete(id);FRIENDS.add(id);renderBadges()}else{await q(sb.from('friendships').insert({requester:ME.id,addressee:id}));PENDING_OUT.add(id)}
 t.outerHTML='<span class="ptag">გაგზავნილია</span>';if(FSW?.p){FSW.p.people++;const n=$('#fs_n');if(n){n.textContent=Math.min(FSW.p.people,5);pop(n.parentElement)}if(FSW.p.people===5)toast('ყოჩაღ! 5 ადამიანი დაემატა')}}catch(e){toast(errMsg(e));t.disabled=false}};
A.fspost=t=>{const k=t.dataset.k;const text=k!=null?FS_IDEAS()[+k]||'':'';FSW=null;compose({text})};
