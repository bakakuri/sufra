/* help board: blood donors, lost and found pets and things, volunteers; alerts go to people nearby who opted in */
const HKINDS=[['blood','საჭიროა სისხლი','🩸'],['lost_pet','დაიკარგა ცხოველი','🐾'],['found_pet','ნაპოვნია ცხოველი','🐶'],['lost_item','დაიკარგა ნივთი','🔑'],['found_item','ნაპოვნია ნივთი','📦'],['volunteer','საჭიროა მოხალისე','🤝'],['other','სხვა თხოვნა','💬']];
const HFILT=[['','ყველა'],['blood','🩸 სისხლი'],['pets','🐾 ცხოველები'],['items','🔑 ნივთები'],['volunteer','🤝 მოხალისეობა'],['other','💬 სხვა']];
const BLOOD=['O-','O+','A-','A+','B-','B+','AB-','AB+'];
const hk=k=>HKINDS.find(x=>x[0]===k)||HKINDS[6];
PG.help={r(){S.hq=S.hq||{f:'',region:ME.home_region||'',done:false};const f=S.hq;
 view.innerHTML=pgHead('დახმარება',`<button class="btn sm" data-a="page" data-p="helpnew">${ic('plus')}თხოვნა</button>`)+`<section class="hhero"><span class="hhico">${ic('help')}</span><div class="grow"><b>ერთმანეთის გვერდით</b><span class="sub" id="hhst">სასწრაფო თხოვნები შენს რეგიონში</span></div><button class="btn sm ghost" data-a="helpset">${ic('bell')}შეტყობინებები</button></section>
 <div class="chipsbar" role="group" aria-label="ტიპი">${HFILT.map(([k,l])=>`<button data-a="hfilt" data-k="${k}" aria-pressed="${f.f===k}">${l}</button>`).join('')}</div>
 <div class="hbar"><label class="fld" style="flex:1">რეგიონი<select id="hreg"><option value="">ყველა რეგიონი</option>${REGIONS.map(r=>`<option${f.region===r?' selected':''}>${r}</option>`).join('')}</select></label><label class="chk"><input type="checkbox" id="hdone"${f.done?' checked':''}><span>მოგვარებულიც</span></label></div><div id="hlb">${skel(3)}</div>`;
 $('#hreg').onchange=e=>{f.region=e.target.value;loadHelp()};$('#hdone').onchange=e=>{f.done=e.target.checked;loadHelp()};loadHelp();
 q(sb.from('helpers').select('*').eq('user_id',ME.id).maybeSingle()).then(h=>{const el=$('#hhst');if(!el)return;S.helper=h;const on=h&&h.region&&(h.notify_blood||h.notify_pets||h.notify_volunteer);el.textContent=on?`შეტყობინებები ჩართულია · ${h.region}${h.notify_blood&&h.blood_type?' · დონორი '+h.blood_type:''}`:'ჩართე შეტყობინებები და გაიგებ, როცა შენს მახლობლად დახმარება სჭირდებათ'}).catch(()=>{})}};
A.hfilt=t=>{S.hq.f=t.dataset.k;$$('[data-a="hfilt"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)));loadHelp()};
const hmedia=h=>(Array.isArray(h.media)?h.media:[]).filter(u=>typeof u==='string'&&/^https:\/\//i.test(u));
const helpCard=h=>{const k=hk(h.kind),img=hmedia(h)[0];return `<button class="hcard${h.urgent&&h.status==='open'?' urgent':''}" data-a="page" data-p="helpreq" data-arg="${h.id}"><span class="hkico k-${h.kind}">${k[2]}</span><span class="grow"><span class="htags"><span class="ptag">${k[1]}</span>${h.blood_type?`<span class="ptag blood">${h.blood_type}</span>`:''}${h.urgent&&h.status==='open'?'<span class="ptag warn">სასწრაფო</span>':''}${h.status==='resolved'?'<span class="ptag ok">მოგვარდა</span>':''}</span><b>${esc(h.title)}</b><span class="sub">${esc(h.region)}${h.city&&h.city!==h.region?' · '+esc(h.city):''} · ${ago(h.created_at)}</span></span>${img&&!ECO()?`<img src="${esc(img)}" alt="" loading="lazy">`:''}</button>`};
async function loadHelp(){const el=$('#hlb');if(!el)return;el.innerHTML=skel(3);const f=S.hq;
 try{let b=sb.from('help_requests').select('id,author,kind,title,region,city,blood_type,urgent,status,media,created_at').eq('hidden',false);
  if(!f.done)b=b.eq('status','open').gt('expires_at',new Date().toISOString());if(f.region)b=b.eq('region',f.region);
  if(f.f==='pets')b=b.in('kind',['lost_pet','found_pet']);else if(f.f==='items')b=b.in('kind',['lost_item','found_item']);else if(f.f)b=b.eq('kind',f.f);
  const rows=await q(b.order('status',{ascending:false}).order('urgent',{ascending:false}).order('created_at',{ascending:false}).limit(60));if(!el.isConnected)return;
  el.innerHTML=rows.length?`<div class="hlist">${rows.map(helpCard).join('')}</div>`:empty(f.region?`${esc(f.region)}: ღია თხოვნა არ არის`:'ღია თხოვნა არ არის','კარგი ამბავია. თუ დახმარება გჭირდება, დაწერე.',`<button class="btn" data-a="page" data-p="helpnew">${ic('plus')}თხოვნის დაწერა</button>`);staggerIn($$('.hcard',el).slice(0,8))}
 catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
A.helpset=async()=>{let h=S.helper;try{h=await q(sb.from('helpers').select('*').eq('user_id',ME.id).maybeSingle())}catch(e){}h=h||{region:ME.home_region||'',blood_type:null,notify_blood:false,notify_pets:false,notify_volunteer:false};
 sheet(head('შეტყობინებები დახმარებაზე')+`<div class="ph-body"><p class="hint" style="padding:0">როცა შენს რეგიონში ვინმე დახმარებას ითხოვს, შეტყობინებას მიიღებ.</p>
 <label class="fld">ჩემი რეგიონი<select id="hs_r"><option value="">—</option>${REGIONS.map(r=>`<option${h.region===r?' selected':''}>${r}</option>`).join('')}</select></label>
 <label class="chk"><input type="checkbox" id="hs_b"${h.notify_blood?' checked':''}><span>🩸 სისხლის დონორი ვარ</span></label>
 <label class="fld" id="hs_btw"${h.notify_blood?'':' hidden'}>სისხლის ჯგუფი<select id="hs_bt"><option value="">—</option>${BLOOD.map(b=>`<option${h.blood_type===b?' selected':''}>${b}</option>`).join('')}</select></label>
 <label class="chk"><input type="checkbox" id="hs_p"${h.notify_pets?' checked':''}><span>🐾 დაკარგული და ნაპოვნი ცხოველები</span></label>
 <label class="chk"><input type="checkbox" id="hs_v"${h.notify_volunteer?' checked':''}><span>🤝 მოხალისეობა</span></label>
 <p class="note">სისხლის ჯგუფს ვერავინ ნახავს. ის მხოლოდ შესაბამისი თხოვნის შეტყობინებისთვის გამოიყენება. სისხლის ჩაბარებამდე გაიარე ექიმის კონსულტაცია.</p></div>
 <div class="ph-foot">${S.helper?'<button class="btn ghost" id="hs_off">ყველას გამორთვა</button>':''}<span class="sp"></span><button class="btn" id="hs_ok">შენახვა</button></div>`,'short');
 $('#hs_b').onchange=e=>{$('#hs_btw').hidden=!e.target.checked};
 const done=x=>{S.helper=x;closeSheet();if(S.page?.id==='help')rp()};
 if($('#hs_off'))$('#hs_off').onclick=async()=>{try{await q(sb.from('helpers').delete().eq('user_id',ME.id));toast('გამოირთო');done(null)}catch(e){toast(errMsg(e))}};
 $('#hs_ok').onclick=async()=>{const row={user_id:ME.id,region:$('#hs_r').value,blood_type:$('#hs_bt').value||null,notify_blood:$('#hs_b').checked,notify_pets:$('#hs_p').checked,notify_volunteer:$('#hs_v').checked,updated_at:new Date().toISOString()};
  if((row.notify_blood||row.notify_pets||row.notify_volunteer)&&!row.region){toast('აირჩიე რეგიონი');return}if(row.notify_blood&&!row.blood_type){toast('აირჩიე სისხლის ჯგუფი');return}
  try{await q(sb.from('helpers').upsert(row,{onConflict:'user_id'}));toast('შენახულია. მადლობა!');done(row)}catch(e){toast(errMsg(e))}}};

PG.helpnew={r(){let kind='blood';const files=[];
 view.innerHTML=pgHead('დახმარების თხოვნა')+`<form class="form" id="hnf"><div class="hkpick" role="group" aria-label="რა გჭირდება">${HKINDS.map(([k,l,e])=>`<button type="button" data-hk="${k}" aria-pressed="${k===kind}"><span>${e}</span>${l}</button>`).join('')}</div>
 <label class="fld">მოკლედ<input id="hn_t" maxlength="100" required placeholder="მაგ. საჭიროა A+ სისხლი რესპუბლიკურ საავადმყოფოში"></label>
 <label class="fld" id="hn_btw">სისხლის ჯგუფი<select id="hn_bt"><option value="">ნებისმიერი</option>${BLOOD.map(b=>`<option>${b}</option>`).join('')}</select></label>
 <label class="fld">დეტალები<textarea id="hn_b" maxlength="1500" rows="5" placeholder="სად, როდის, ვის მიმართონ. ცხოველისთვის: ჯიში, ფერი, სად ნახეს ბოლოს"></textarea></label>
 <div class="frow"><label class="fld">რეგიონი<select id="hn_r" required>${REGIONS.map(r=>`<option${(ME.home_region||'თბილისი')===r?' selected':''}>${r}</option>`).join('')}</select></label><label class="fld">ქალაქი ან სოფელი<input id="hn_c" maxlength="60" list="hncities" value="${esc(ME.city||'')}"></label></div><datalist id="hncities">${CITIES.map(c=>`<option value="${c}">`).join('')}</datalist>
 <label class="fld">საკონტაქტო (არასავალდებულო)<input id="hn_ct" maxlength="60" inputmode="tel" placeholder="ტელეფონი ან სხვა კონტაქტი"></label>
 <label class="chk"><input type="checkbox" id="hn_u"><span>სასწრაფოა</span></label>
 <div class="fld">ფოტოები<div class="cattach" id="hn_ph"></div><button type="button" class="btn sm ghost" id="hn_img" style="align-self:flex-start">${ic('image')}ფოტოს დამატება</button></div>
 <p class="note">თხოვნა 30 დღე ჩანს. შენს რეგიონში შეტყობინებას მიიღებენ ისინი, ვინც ამ ტიპის დახმარებაზე დათანხმდა. პირად მონაცემებს ფრთხილად გაუზიარე.</p>
 <button class="btn" id="hn_ok">${ic('send')}გამოქვეყნება</button></form>`;
 $$('[data-hk]').forEach(b=>b.onclick=()=>{kind=b.dataset.hk;$$('[data-hk]').forEach(z=>z.setAttribute('aria-pressed',String(z===b)));$('#hn_btw').hidden=kind!=='blood';$('#hn_u').checked=kind==='blood'});$('#hn_u').checked=true;
 const drawPh=()=>{$('#hn_ph').innerHTML=files.map((f,i)=>`<div class="catt"><img src="${f.url}" alt=""><button type="button" data-hr="${i}" aria-label="წაშლა">${ic('x')}</button></div>`).join('');$$('[data-hr]').forEach(b=>b.onclick=()=>{files.splice(+b.dataset.hr,1);drawPh()})};
 $('#hn_img').onclick=async()=>{if(files.length>=4){toast('მაქსიმუმ 4 ფოტო');return}const b=await pickImage({max:ECO()?1080:1400});if(b){files.push({blob:b,url:URL.createObjectURL(b)});drawPh()}};
 $('#hnf').onsubmit=async e=>{e.preventDefault();const title=$('#hn_t').value.trim();if(title.length<4){toast('დაწერე, რა გჭირდება');return}const b=$('#hn_ok');b.disabled=true;
  try{const media=[];for(let i=0;i<files.length;i++){b.textContent=`იტვირთება ${i+1}/${files.length}…`;media.push(await uploadBlob(files[i].blob,'jpg'))}
   const r=await q(sb.from('help_requests').insert({author:ME.id,kind,title,body:$('#hn_b').value.trim(),media,region:$('#hn_r').value,city:$('#hn_c').value.trim(),blood_type:kind==='blood'?($('#hn_bt').value||null):null,contact:$('#hn_ct').value.trim(),urgent:$('#hn_u').checked}).select('id').single());
   toast('თხოვნა გამოქვეყნდა. იმედია, მალე მოგვარდება');openPage('helpreq',r.id,['help'])}catch(x){toast(/too_many/.test(x.message)?'დღეში მაქსიმუმ 3 თხოვნა შეიძლება':errMsg(x));b.disabled=false;b.innerHTML=`${ic('send')}გამოქვეყნება`}}}};

PG.helpreq={r(id){id=+id;view.innerHTML=pgHead('თხოვნა')+`<div id="hrb">${skel(2)}</div>`;openHelp(id)}};
async function openHelp(id){const el=$('#hrb');let h,offers=[];try{[h,offers]=await Promise.all([q(sb.from('help_requests').select('*').eq('id',id).maybeSingle()),q(sb.from('help_offers').select('user_id,note,created_at').eq('request_id',id).order('created_at'))])}catch(e){if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e));return}
 if(!el||!el.isConnected)return;if(!h){el.innerHTML=empty('თხოვნა ვერ მოიძებნა','შეიძლება წაიშალა.');return}S.help=h;
 await loadProfiles([h.author,...offers.map(o=>o.user_id)]);const mine=h.author===ME.id,k=hk(h.kind),my=offers.find(o=>o.user_id===ME.id),open=h.status==='open';
 const tel=/^[+\d][\d\s()-]{5,}$/.test(h.contact)?h.contact.replace(/[^\d+]/g,''):'';
 el.innerHTML=`<section class="hdet${h.urgent&&open?' urgent':''}"><div class="htags"><span class="hkico k-${h.kind}">${k[2]}</span><span class="ptag">${k[1]}</span>${h.blood_type?`<span class="ptag blood">${h.blood_type}</span>`:''}${h.urgent&&open?'<span class="ptag warn">სასწრაფო</span>':''}${!open?'<span class="ptag ok">მოგვარდა</span>':''}</div>
 <h1>${esc(h.title)}</h1><p class="muted">${esc(h.region)}${h.city&&h.city!==h.region?' · '+esc(h.city):''} · ${ago(h.created_at)}</p>
 <div class="row" style="padding:8px 0"><button data-a="user" data-u="${h.author}">${av(h.author,40)}</button><span class="grow"><b>${esc(pname(h.author))}${vb(h.author)}</b><span class="sub">ავტორი</span></span>${mine?'':`<button class="btn sm ghost" data-a="chatwith" data-u="${h.author}">${ic('msg')}მიწერა</button>`}</div>
 ${h.body?tx(h.body):''}${hmedia(h).length?`<div class="pgrid">${hmedia(h).map(u=>`<button data-a="imgview" data-src="${esc(u)}"><img src="${esc(u)}" alt="" loading="lazy"></button>`).join('')}</div>`:''}
 ${h.contact?`<p class="hcontact">${ic('phone')}${tel?`<a href="tel:${esc(tel)}">${esc(h.contact)}</a>`:esc(h.contact)}</p>`:''}
 <div class="pbtns">${mine?(open?`<button class="btn" data-a="hresolve">${ic('check')}მოგვარდა</button>`:''):open?(my?`<button class="btn ghost" data-a="hunoffer">${ic('check')}გამოეხმაურე · გაუქმება</button>`:`<button class="btn" data-a="hoffer">${ic('help')}შემიძლია დახმარება</button>`):''}<button class="btn ghost" data-a="hshare">${ic('share')}გაზიარება</button>${mine?`<button class="btn ghost" data-a="hdel" aria-label="წაშლა">${ic('trash')}</button>`:`<button class="btn ghost" data-a="report" data-type="help" data-id="${h.id}" aria-label="საჩივარი">${ic('flag')}</button>`}${isStaff()&&!mine?`<button class="btn ghost" data-a="modhide" data-type="help" data-id="${h.id}" data-h="${h.hidden?0:1}">${h.hidden?'გამოჩენა':'დამალვა'}</button>`:''}</div></section>
 ${mine?`<h3 class="sec2">გამოეხმაურნენ · ${offers.length}</h3><div class="list">${offers.map(o=>`<div class="row">${av(o.user_id,40)}<span class="grow"><b>${esc(pname(o.user_id))}</b><span class="sub">${o.note?esc(o.note)+' · ':''}${ago(o.created_at)}</span></span><button class="btn sm" data-a="chatwith" data-u="${o.user_id}">${ic('msg')}მიწერა</button></div>`).join('')||'<p class="muted">ჯერ არავინ. გაუზიარე მეგობრებს, რომ მეტმა ნახოს.</p>'}</div>`:''}
 <p class="note" style="padding:8px 16px 24px">სუფრა ამოწმებს საჩივრებს, მაგრამ თხოვნების სისწორეს ვერ ადასტურებს. ფულს წინასწარ ნუ გადარიცხავ.</p>`}
A.hoffer=()=>{const h=S.help;sheet(head('დახმარება')+`<div class="ph-body"><p>${esc(pname(h.author))} მიიღებს შეტყობინებას, რომ შეგიძლია დახმარება.</p><label class="fld">მოკლე შეტყობინება (არასავალდებულო)<textarea id="ho_n" maxlength="300" rows="3" placeholder="მაგ. ჩემი ჯგუფია A+, შემიძლია ხვალ დილით მოსვლა"></textarea></label></div><div class="ph-foot"><span class="sp"></span><button class="btn" id="ho_ok">${ic('send')}გაგზავნა</button></div>`,'short');
 $('#ho_ok').onclick=async()=>{const b=$('#ho_ok');b.disabled=true;try{await q(sb.from('help_offers').insert({request_id:h.id,user_id:ME.id,note:$('#ho_n').value.trim()}));closeSheet();toast('ავტორს ეცნობა. მადლობა!');confetti();openHelp(h.id)}catch(e){toast(errMsg(e));b.disabled=false}}};
A.hunoffer=async()=>{const h=S.help;try{await q(sb.from('help_offers').delete().eq('request_id',h.id).eq('user_id',ME.id));openHelp(h.id)}catch(e){toast(errMsg(e))}};
A.hresolve=()=>{const h=S.help;confirmSheet('მოგვარდა?','თხოვნა დაიხურება და ვინც გამოგეხმაურა, მადლობის შეტყობინებას მიიღებს.','მოგვარდა',async()=>{await q(sb.from('help_requests').update({status:'resolved'}).eq('id',h.id));toast('ძალიან კარგი!');confetti();openHelp(h.id)})};
A.hdel=()=>{const h=S.help;confirmSheet('თხოვნის წაშლა','თხოვნა წაიშლება ყველასთვის.','წაშლა',async()=>{await q(sb.from('help_requests').delete().eq('id',h.id));openPage('help')},true)};
A.hshare=()=>{const h=S.help;if(h)shareLink(location.origin+'/#helpreq-'+h.id,h.title)};
