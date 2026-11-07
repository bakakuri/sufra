/* the shop for coins: only sellers the admin lets in, every product checked by the admin first.
   Paying holds the coins until the buyer confirms (or 7 days after sending); then the seller gets the price minus 10%.
   Before sending, either side can cancel; a problem goes to the admin. The market (lari, meeting in person) stays separate. */
const SHOP={seller:undefined,tab:'all',q:''};
const SH_TABS=[['all','store','პროდუქტები'],['buy','bookmark','შესყიდვები'],['sell','coin','გაყიდვები',1],['mine','grid','ჩემი პროდუქტები',1]];
const OST={paid:['გადახდილია','clock','გამყიდველი ნივთს გამოგზავნის. მონეტები მანამდე გაყინულია.'],shipped:['გამოგზავნილია','send','მიღებისას დააჭირე „მივიღე“.'],
 completed:['დასრულებულია','check',''],cancelled:['გაუქმებულია','x','მონეტები მყიდველს დაუბრუნდა.'],disputed:['დავა','flag','ადმინისტრატორი განიხილავს.'],refunded:['დაბრუნდა','x','მონეტები მყიდველს დაუბრუნდა.']};
const IST={pending:['შემოწმებაზე','clock'],active:['ჩანს მაღაზიაში','check'],rejected:['არ დადასტურდა','x'],paused:['დაპაუზებულია','pause'],removed:['წაშლილია','trash']};
const shPic=it=>{const m=(it.media||[])[0];return m?`<img src="${esc(mSm(m))}" alt="" loading="lazy">`:`<span class="shnopic">${ic('store')}</span>`};
const shCoin=n=>`<span class="shcoin">${ic('coin')}${nf(n)}</span>`;
async function shopMe(force){if(SHOP.seller!==undefined&&!force)return SHOP.seller;try{SHOP.seller=await q(sb.from('shop_sellers').select('name,about,city,status,note,created_at').eq('user_id',ME.id).maybeSingle())}catch(e){SHOP.seller=null}return SHOP.seller}
const shopSeller=()=>SHOP.seller&&SHOP.seller.status==='approved';

PG.shop={async r(tab){if(tab)SHOP.tab=tab;view.innerHTML=pgHead('მაღაზია',`<span id="shhd"></span>`)+`<div class="archtabs shtabs" role="tablist" aria-label="მაღაზია" id="shtabs"></div><div id="shb">${skel(2)}</div>`;
 await shopMe(true);if(!$('#shtabs'))return;
 $('#shhd').innerHTML=shopSeller()?`<button class="btn sm" data-a="page" data-p="shopedit">${ic('plus')}პროდუქტი</button>`:`<button class="btn sm ghost" data-a="page" data-p="shopapply">${ic('store')}გაყიდვა</button>`;
 if(!shopSeller()&&['sell','mine'].includes(SHOP.tab))SHOP.tab='all';drawShopTabs();loadShop()}};
function drawShopTabs(){const el=$('#shtabs');if(!el)return;el.innerHTML=SH_TABS.filter(t=>!t[3]||shopSeller()).map(([k,i,l])=>`<button role="tab" data-a="shtab" data-k="${k}" aria-selected="${SHOP.tab===k}">${ic(i)}<span>${l}</span></button>`).join('')}
A.shtab=t=>{SHOP.tab=t.dataset.k;drawShopTabs();loadShop()};
async function loadShop(){const el=$('#shb');if(!el)return;el.innerHTML=skel(2);const k=SHOP.tab;
 try{if(k==='all'){let b=sb.from('shop_items').select('id,seller,title,price,media,stock,sold,created_at').eq('status','active').order('created_at',{ascending:false}).limit(80);
   const qv=clean(SHOP.q);if(qv)b=b.ilike('title',`%${qv}%`);const rows=await q(b);const names=await shopNames(rows.map(r=>r.seller));if(!$('#shb'))return;
   el.innerHTML=`<p class="archnote">${ic('shield')}მონეტები გამყიდველს მხოლოდ მაშინ ერიცხება, როცა ნივთს მიიღებ. პრობლემის დროს ადმინისტრატორი დაგეხმარება.</p>
    <form class="search" id="shqf" role="search"><input class="field" id="shq" type="search" placeholder="რას ეძებ?" value="${esc(SHOP.q)}" aria-label="ძიება მაღაზიაში"></form>
    ${rows.length?`<div class="mgrid spgrid">${rows.map(i=>`<button class="mitem shitem" data-a="page" data-p="shopitem" data-arg="${i.id}">${shPic(i)}${i.stock<1?'<em class="shout">ამოიწურა</em>':''}<span class="price">${shCoin(i.price)}</span><span class="t">${esc(i.title)}</span><span class="sub">${esc(names[i.seller]||pname(i.seller))}</span></button>`).join('')}</div>`
     :empty(qv?'ვერაფერი მოიძებნა':'მაღაზია ჯერ ცარიელია',qv?'':'პირველი პროდუქტები მალე გამოჩნდება.',shopSeller()?'<button class="btn" data-a="page" data-p="shopedit">პროდუქტის დამატება</button>':'')}`;
   const f=$('#shqf');if(f){f.onsubmit=e=>{e.preventDefault();loadShop()};$('#shq').oninput=e=>{SHOP.q=e.target.value;clearTimeout(SHOP.t);SHOP.t=setTimeout(()=>{loadShop().then(()=>{const i=$('#shq');if(i){i.focus();i.setSelectionRange(i.value.length,i.value.length)}})},400)}}return}
  if(k==='buy'||k==='sell'){const rows=await q(sb.from('shop_orders').select('*').eq(k==='buy'?'buyer':'seller',ME.id).order('created_at',{ascending:false}).limit(60));
   await loadProfiles(rows.map(r=>k==='buy'?r.seller:r.buyer));if(!$('#shb'))return;
   el.innerHTML=rows.length?`<div class="list shorders">${rows.map(o=>orderRow(o,k)).join('')}</div>`:empty(k==='buy'?'შესყიდვები ჯერ არ გაქვს':'გაყიდვები ჯერ არ გაქვს',k==='buy'?'მაღაზიაში ნივთს მონეტებით იყიდი.':'როცა ვინმე იყიდის, აქ გამოჩნდება.',k==='buy'?'<button class="btn" data-a="shtab" data-k="all">პროდუქტების ნახვა</button>':'');return}
  const rows=await q(sb.from('shop_items').select('id,title,price,media,stock,sold,status,note,approved,created_at').eq('seller',ME.id).neq('status','removed').order('created_at',{ascending:false}));if(!$('#shb'))return;
  el.innerHTML=`<p class="archnote">${ic('store')}${esc(SHOP.seller.name)} · ყოველი ახალი პროდუქტი და ცვლილება ჯერ ადმინისტრატორთან მიდის. გაყიდვიდან 10% Peera-ს საკომისიოა.</p>`+(rows.length?`<div class="list">${rows.map(i=>`<button class="row shmine" data-a="page" data-p="shopedit" data-arg="${i.id}"><span class="shthumb">${shPic(i)}</span><span class="grow"><b>${esc(i.title)}</b><span class="sub">${shCoin(i.price)} · მარაგი ${i.stock} · გაიყიდა ${i.sold}${i.status==='rejected'&&i.note?' · '+esc(i.note):''}</span></span><span class="ist s-${i.status}">${ic(IST[i.status][1])}${IST[i.status][0]}</span></button>`).join('')}</div>`
   :empty('პროდუქტები ჯერ არ გაქვს','','<button class="btn" data-a="page" data-p="shopedit">პროდუქტის დამატება</button>'))}
 catch(e){if($('#shb'))el.innerHTML=empty('ვერ ჩაიტვირთა',esc(errMsg(e)))}}
async function shopNames(ids){const u=[...new Set(ids)].filter(Boolean);if(!u.length)return {};await loadProfiles(u);try{const r=await q(sb.from('shop_sellers').select('user_id,name').in('user_id',u));return Object.fromEntries(r.map(x=>[x.user_id,x.name]))}catch(e){return {}}}
const orderRow=(o,k)=>{const s=OST[o.status]||[o.status,'clock'];const who=k==='buy'?o.seller:o.buyer;
 return `<button class="row shord${(k==='sell'&&o.status==='paid')||(k==='buy'&&o.status==='shipped')?' todo':''}" data-a="shord" data-id="${o.id}"><span class="shthumb">${o.photo?`<img src="${esc(o.photo)}" alt="" loading="lazy">`:`<span class="shnopic">${ic('store')}</span>`}</span><span class="grow"><b>${esc(o.title)}</b><span class="sub">${shCoin(o.price)} · ${k==='buy'?'გამყიდველი':'მყიდველი'}: ${esc(pname(who))} · ${ago(o.created_at)}</span></span><span class="ist o-${o.status}">${ic(s[1])}${s[0]}</span></button>`};

/* ---------- a product ---------- */
PG.shopitem={r(id){view.innerHTML=pgHead('პროდუქტი')+`<div id="sib">${skel(2)}</div>`;loadShopItem(+id)}};
async function loadShopItem(id){const el=$('#sib');if(!el)return;let it,sl;
 try{it=await q(sb.from('shop_items').select('*').eq('id',id).maybeSingle());if(it){[sl]=await Promise.all([q(sb.from('shop_sellers').select('name,city,about').eq('user_id',it.seller).maybeSingle()),loadProfiles([it.seller])])}}catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',esc(errMsg(e)));return}
 if(!$('#sib'))return;if(!it){el.innerHTML=empty('პროდუქტი აღარ არის','შეიძლება წაიშალა ან დროებით შეჩერდა.');return}
 const mine=it.seller===ME.id,h=$('.pghead h2');if(h)h.textContent=it.title;const live=it.status==='active';
 el.innerHTML=`${(it.media||[]).length?`<div class="mgal shgal">${it.media.map(m=>mediaHTML(m,'pimg')).join('')}</div>`:''}
 <section class="shinfo"><b class="shprice">${shCoin(it.price)}</b><h3>${esc(it.title)}</h3>
  <p class="sub">${it.stock>0?`მარაგში ${it.stock}`:'ამოიწურა'}${it.sold?` · გაიყიდა ${it.sold}`:''}${!live?` · ${IST[it.status][0]}`:''}</p>
  ${it.about?`<div class="shabout">${tx(it.about)}</div>`:''}
  ${it.delivery?`<p class="shdel">${ic('route')}<span><b>მიწოდება</b>${esc(it.delivery)}</span></p>`:''}</section>
 <button class="row shsel" data-a="user" data-u="${it.seller}">${av(it.seller,44)}<span class="grow"><b>${esc(sl?.name||pname(it.seller))}${vb(it.seller)}</b><span class="sub">${esc(pname(it.seller))}${sl?.city?' · '+esc(sl.city):''}</span></span></button>
 <p class="archnote">${ic('shield')}გადახდისას მონეტები გაიყინება. გამყიდველი მათ მაშინ მიიღებს, როცა „მივიღე“-ს დააჭერ, ან გაგზავნიდან 7 დღეში. მანამდე შეგიძლია გააუქმო, ან პრობლემა მიუთითო.</p>
 <div class="shbuybar">${mine?`<button class="btn" data-a="page" data-p="shopedit" data-arg="${it.id}">${ic('edit')}რედაქტირება</button>`
  :`<span class="grow"><small>ბალანსი</small><b>${nf(ME.coins)}</b></span><button class="btn" data-a="shbuy" data-id="${it.id}" data-p="${it.price}" data-t="${esc(it.title)}"${!live||it.stock<1?' disabled':''}>${it.stock<1?'ამოიწურა':`ყიდვა · ${nf(it.price)}`}</button>`}</div>`}
A.shbuy=t=>{const id=+t.dataset.id,price=+t.dataset.p,short=price-(ME.coins||0);
 if(short>0){toast(`აკლია ${nf(short)} მონეტა`);return}
 const last=store.get('shdel','')||'';
 sheet(head('ყიდვა')+`<form class="ph-body form" id="shbf"><p><b>${esc(t.dataset.t)}</b> · ${shCoin(price)}</p>
  <label class="fld">სად და როგორ მიიღებ<textarea id="shb_d" rows="3" maxlength="500" placeholder="სახელი, ტელეფონი, მისამართი ან სად შეხვდებით">${esc(last)}</textarea></label>
  <p class="note">ამას მხოლოდ გამყიდველი და ადმინისტრაცია ნახავს. მონეტები ჩამოგეჭრება და გაყინული იქნება, სანამ ნივთს არ მიიღებ.</p>
  <button class="btn">${ic('check')}გადახდა · ${nf(price)}</button></form>`,'short');
 $('#shbf').onsubmit=async e=>{e.preventDefault();const d=$('#shb_d').value.trim();if(d.length<5){toast('დაწერე, სად და როგორ მიიღებ');return}const b=$('#shbf .btn');b.disabled=true;
  try{const r=await rpc('shop_buy',{p_item:id,p_delivery:d});store.set('shdel',d);if(r&&r.coins!=null)setCoins(r.coins);closeSheet();toast('გადახდილია. გამყიდველი შეტყობინებას მიიღებს');confetti();openPage('shop','buy')}catch(x){b.disabled=false;toast(errMsg(x))}}};

/* ---------- an order: what happened, and the next step for whoever's turn it is ---------- */
A.shord=t=>shopOrder(+t.dataset.id);
async function shopOrder(id){let o;try{o=await q(sb.from('shop_orders').select('*').eq('id',id).maybeSingle())}catch(e){toast(errMsg(e));return}if(!o){toast('შეკვეთა ვერ მოიძებნა');return}
 await loadProfiles([o.buyer,o.seller]);const buyer=o.buyer===ME.id,other=buyer?o.seller:o.buyer,s=OST[o.status]||[o.status,'clock',''];
 const auto=o.status==='shipped'&&o.shipped_at?new Date(new Date(o.shipped_at).getTime()+7*864e5):null;
 const acts=[];if(buyer&&o.status==='shipped')acts.push(['received','btn',ic('check')+'მივიღე']);if(!buyer&&o.status==='paid')acts.push(['ship','btn',ic('send')+'გავგზავნე']);
 if(o.status==='paid')acts.push(['cancel','btn ghost',ic('x')+'გაუქმება']);if(buyer&&['paid','shipped'].includes(o.status))acts.push(['dispute','btn ghost',ic('flag')+'პრობლემაა']);
 sheet(head('შეკვეთა #'+o.id)+`<div class="ph-body shordsheet"><div class="row" style="padding:0">${o.photo?`<span class="shthumb"><img src="${esc(o.photo)}" alt=""></span>`:''}<span class="grow"><b>${esc(o.title)}</b><span class="sub">${shCoin(o.price)} · ${ago(o.created_at)}</span></span></div>
  <p class="shst"><span class="ist o-${o.status}">${ic(s[1])}${s[0]}</span> ${esc(s[2])}${auto?` თუ პრობლემას არ მიუთითებ, შეკვეთა თავისით დასრულდება (${auto.getDate()} ${MONTHS[auto.getMonth()]}).`:''}</p>
  <div class="pocopy"><span class="grow"><small>${buyer?'მიწოდება (შენ მიუთითე)':'მიწოდება: მყიდველის მონაცემები'}</small><span>${esc(o.delivery)}</span></span>${buyer?'':`<button class="ibtn sm" data-a="adpocopy" data-v="${esc(o.delivery)}" aria-label="კოპირება">${ic('copy')}</button>`}</div>
  ${o.ship_note?`<p class="note"><b>გაგზავნის შენიშვნა:</b> ${esc(o.ship_note)}</p>`:''}${o.dispute?`<p class="note"><b>პრობლემა:</b> ${esc(o.dispute)}</p>`:''}${o.admin_note?`<p class="note"><b>ადმინისტრაცია:</b> ${esc(o.admin_note)}</p>`:''}
  ${o.status==='completed'&&!buyer&&o.payout!=null?`<p class="note">მიიღე ${nf(o.payout)} მონეტა (10% საკომისიოს გარეშე).</p>`:''}
  <div class="shnote" id="sho_nw" hidden><label class="fld"><span id="sho_nl"></span><textarea id="sho_n" rows="2" maxlength="300"></textarea></label></div>
  <div class="shacts">${acts.map(([a,c,l])=>`<button class="${c}" data-a="shoact" data-act="${a}" data-id="${o.id}">${l}</button>`).join('')}<button class="btn ghost" data-a="shochat" data-u="${other}" data-t="${esc(o.title)}">${ic('msg')}${buyer?'გამყიდველს':'მყიდველს'} მიწერა</button></div></div>`,'short')}
A.shochat=t=>{closeSheet();openChatWith(t.dataset.u,`შეკვეთა „${t.dataset.t}“: `)};
A.shoact=async t=>{const a=t.dataset.act,id=+t.dataset.id,w=$('#sho_nw');
 // shipping and a problem take a few words first; the same button sends them
 if((a==='ship'||a==='dispute')&&w&&w.hidden){w.hidden=false;$('#sho_nl').textContent=a==='ship'?'როგორ გაგზავნე (არასავალდებულო): ფოსტა, კურიერი, ნომერი':'რა მოხდა? ადმინისტრატორი ამას ნახავს';$('#sho_n').focus();$$('[data-a="shoact"]').forEach(b=>{if(b!==t)b.hidden=true});t.innerHTML=a==='ship'?`${ic('send')}გაგზავნილად მონიშვნა`:`${ic('flag')}პრობლემის გაგზავნა`;return}
 const note=$('#sho_n')?.value.trim()||null;if(a==='dispute'&&(!note||note.length<5)){toast('დაწერე, რა მოხდა');return}
 const run=async()=>{await rpc('shop_order_act',{p_order:id,p_act:a,p_note:note});closeSheet();toast({ship:'მონიშნულია გაგზავნილად',received:'დასრულდა. მადლობა!',cancel:'შეკვეთა გაუქმდა, მონეტები დაბრუნდა',dispute:'პრობლემა გაიგზავნა ადმინისტრატორთან'}[a]);if(a==='received')confetti();if(S.page?.id==='shop')loadShop()};
 if(a==='received')return confirmSheet('ნივთი მიიღე?','დადასტურების შემდეგ მონეტები გამყიდველს გადაეცემა და ვეღარ დაბრუნდება.','მივიღე',run);
 if(a==='cancel')return confirmSheet('შეკვეთის გაუქმება','მონეტები მყიდველს სრულად დაუბრუნდება.','გაუქმება',run,true);
 t.disabled=true;try{await run()}catch(e){t.disabled=false;toast(errMsg(e))}};
async function shopOpenOrder(id){if(S.page?.id!=='shop')openPage('shop','buy');setTimeout(()=>shopOrder(+id),300)}

/* ---------- becoming a seller ---------- */
PG.shopapply={async r(){view.innerHTML=pgHead('გაყიდვა მაღაზიაში')+`<div id="sab">${skel(1)}</div>`;const s=await shopMe(true);const el=$('#sab');if(!el)return;
 if(s&&s.status==='approved'){el.innerHTML=`<div class="vcard"><span class="vb" style="width:48px;height:48px">${ic('check')}</span><h3>შენ გამყიდველი ხარ</h3><p class="muted">${esc(s.name)}</p><button class="btn" data-a="page" data-p="shopedit">${ic('plus')}პროდუქტის დამატება</button></div>`;return}
 if(s&&s.status==='blocked'){el.innerHTML=`<div class="vcard"><h3>გაყიდვა შეჩერებულია</h3><p class="muted">${esc(s.note||'')}</p></div>`;return}
 el.innerHTML=`${s&&s.status==='pending'?`<div class="vcard"><h3>განაცხადი განხილვაშია</h3><p class="muted">ადმინისტრატორი გადაწყვეტს და შეტყობინებას მიიღებ. ქვემოთ შეგიძლია შეცვალო.</p></div>`:''}
 ${s&&s.status==='rejected'?`<p class="aerr" style="margin:12px 16px">წინა განაცხადი არ დადასტურდა${s.note?': '+esc(s.note):''}. შეგიძლია ხელახლა გაგზავნო.</p>`:''}
 <form class="form" id="saf"><p class="note">მაღაზიაში გაყიდვა შეუძლიათ მხოლოდ იმათ, ვისაც ადმინისტრატორი დაუშვებს. პირობა: 18 წელი ან მეტი. ყოველი პროდუქტიც შემოწმდება. გაყიდვიდან 10% Peera-ს საკომისიოა.</p>
  <label class="fld">მაღაზიის სახელი<input id="sa_n" maxlength="60" required value="${esc(s?.name||'')}" placeholder="მაგ. ნინოს ხელნაკეთი სამკაულები"></label>
  <label class="fld">რას გაყიდი<textarea id="sa_a" maxlength="500" rows="3" placeholder="რა პროდუქტები, საიდან, როგორ აგზავნი">${esc(s?.about||'')}</textarea></label>
  <label class="fld">ქალაქი<input id="sa_c" list="cities4" maxlength="60" value="${esc(s?.city||ME.city||'')}"></label><datalist id="cities4">${CITIES.map(c=>`<option value="${c}">`).join('')}</datalist>
  <button class="btn" style="align-self:flex-start">${ic('send')}${s?'განახლება':'განაცხადის გაგზავნა'}</button></form>`;
 $('#saf').onsubmit=async e=>{e.preventDefault();const b=$('#saf .btn');b.disabled=true;try{await rpc('shop_apply',{p_name:$('#sa_n').value.trim(),p_about:$('#sa_a').value.trim(),p_city:$('#sa_c').value.trim()});toast('განაცხადი გაიგზავნა');PG.shopapply.r()}catch(x){b.disabled=false;toast(errMsg(x))}}}};

/* ---------- adding and editing a product ---------- */
PG.shopedit={async r(id){id=+id||null;view.innerHTML=pgHead(id?'პროდუქტის რედაქტირება':'ახალი პროდუქტი')+`<div id="seb">${skel(2)}</div>`;
 await shopMe();let it=null;if(id){try{it=await q(sb.from('shop_items').select('*').eq('id',id).eq('seller',ME.id).maybeSingle())}catch(e){}}const el=$('#seb');if(!el)return;
 if(!shopSeller()&&!it){el.innerHTML=empty('ჯერ გამყიდველი არ ხარ','მაღაზიაში გასაყიდად ჯერ განაცხადი გააგზავნე.','<button class="btn" data-a="page" data-p="shopapply">განაცხადი</button>');return}
 const imgs=(it?.media||[]).map(m=>({m}));
 el.innerHTML=`${it?`<p class="shst" style="padding:12px 16px 0"><span class="ist s-${it.status}">${ic(IST[it.status][1])}${IST[it.status][0]}</span>${it.status==='rejected'&&it.note?' '+esc(it.note):''}</p>`:''}
 <form class="form" id="sef"><div class="cattach" id="seimgs"></div><button type="button" class="btn ghost" id="se_add" style="align-self:flex-start">${ic('image')}ფოტოს დამატება (მაქს. 6)</button>
  <label class="fld">სახელი<input id="se_t" required maxlength="100" value="${esc(it?.title||'')}" placeholder="მაგ. ხელნაკეთი თიხის ჭიქა"></label>
  <div class="frow"><label class="fld">ფასი, მონეტა<input id="se_p" type="number" min="10" step="1" inputmode="numeric" required value="${it?.price||''}"></label><label class="fld">მარაგი<input id="se_s" type="number" min="0" max="10000" step="1" inputmode="numeric" value="${it?it.stock:1}"></label></div>
  <small class="pohint" id="se_ph"></small>
  <label class="fld">აღწერა<textarea id="se_a" maxlength="2000" rows="4" placeholder="ზომა, მასალა, მდგომარეობა">${esc(it?.about||'')}</textarea></label>
  <label class="fld">მიწოდება<input id="se_d" maxlength="300" value="${esc(it?.delivery||'')}" placeholder="მაგ. ფოსტით მთელ საქართველოში, თბილისში შეხვედრაც შეიძლება"></label>
  <p class="note">სახელის, ფასის, ფოტოს, აღწერის ან მიწოდების შეცვლის შემდეგ პროდუქტი ხელახლა შემოწმდება. მარაგი თავისუფლად იცვლება.</p>
  <button class="btn" style="align-self:flex-start">${ic('check')}${it?'შენახვა':'შემოწმებაზე გაგზავნა'}</button></form>
 ${it?`<div class="shacts" style="padding:0 16px 24px">${it.status==='active'?`<button class="btn ghost" data-a="sestate" data-id="${it.id}" data-s="paused">${ic('pause')}დაპაუზება</button>`:''}${it.status==='paused'&&it.approved?`<button class="btn ghost" data-a="sestate" data-id="${it.id}" data-s="active">${ic('play')}ისევ ჩვენება</button>`:''}<button class="btn ghost danger" data-a="sestate" data-id="${it.id}" data-s="removed">${ic('trash')}წაშლა</button></div>`:''}`;
 const draw=()=>{$('#seimgs').innerHTML=imgs.map((x,i)=>`<div class="catt"><img src="${x.b?URL.createObjectURL(x.b):esc(mSm(x.m))}" alt=""><button type="button" data-rm="${i}" aria-label="წაშლა">${ic('x')}</button></div>`).join('');$$('[data-rm]',$('#seimgs')).forEach(b=>b.onclick=()=>{imgs.splice(+b.dataset.rm,1);draw()})};draw();
 const ph=()=>{const v=+$('#se_p').value||0;$('#se_ph').textContent=v>=10?`გაყიდვისას მიიღებ ${nf(Math.floor(v*0.9))} მონეტას (10% საკომისიო)`:''};$('#se_p').oninput=ph;ph();
 $('#se_add').onclick=async()=>{if(imgs.length>=6)return;const b=await pickImage({ratios:['1','45','orig'],ratio:'1',max:1400});if(b){imgs.push({b});draw()}};
 $('#sef').onsubmit=async e=>{e.preventDefault();const v=k=>$('#se_'+k).value.trim(),btn=$('#sef>.btn');const price=Math.floor(+v('p')||0);if(price<10){toast('ფასი მინიმუმ 10 მონეტა');return}btn.disabled=true;
  try{const media=[];for(let i=0;i<imgs.length;i++){if(imgs[i].m){media.push(imgs[i].m);continue}btn.textContent=`იტვირთება ${i+1}/${imgs.length}…`;media.push(await uploadMedia(imgs[i].b,'image'))}
   await rpc('shop_item_save',{p_id:it?.id||null,p_title:v('t'),p_about:v('a'),p_price:price,p_media:media,p_stock:Math.max(0,Math.floor(+v('s')||0)),p_delivery:v('d')});
   toast(it?'შენახულია':'გაიგზავნა შემოწმებაზე');SHOP.tab='mine';A.back()}
  catch(x){toast(errMsg(x));btn.disabled=false;btn.innerHTML=`${ic('check')}${it?'შენახვა':'შემოწმებაზე გაგზავნა'}`}}}};
A.sestate=t=>{const s=t.dataset.s,id=+t.dataset.id,run=async()=>{await rpc('shop_item_state',{p_id:id,p_state:s});toast(s==='removed'?'წაიშალა':s==='paused'?'დაპაუზდა':'ისევ ჩანს');if(s==='removed'){SHOP.tab='mine';A.back()}else PG.shopedit.r(id)};
 if(s==='removed')return confirmSheet('პროდუქტის წაშლა','პროდუქტი მაღაზიიდან გაქრება. უკვე გაფორმებული შეკვეთები რჩება.','წაშლა',run,true);run().catch(e=>toast(errMsg(e)))};

/* ---------- admin: sellers, products and problems ---------- */
async function admShop(el){ADM.shk=ADM.shk||'sellers';const k=ADM.shk;
 const [sel,items,disp]=await Promise.all([q(sb.from('shop_sellers').select('*').in('status',k==='sellers'?['pending']:['approved','blocked']).order('created_at')),
  q(sb.from('shop_items').select('*').eq('status','pending').order('updated_at')),q(sb.from('shop_orders').select('*').eq('status','disputed').order('created_at'))]);
 await loadProfiles([...sel.map(s=>s.user_id),...items.map(i=>i.seller),...disp.flatMap(o=>[o.buyer,o.seller])]);if(!el.isConnected)return;
 const pend=k==='sellers'?sel.length:null,days=t=>Math.floor((Date.now()-new Date(t))/864e5);
 const chip=(key,l,n)=>`<button data-a="adshk" data-k="${key}" aria-pressed="${k===key}">${l}${n?` <span class="badge">${n}</span>`:''}</button>`;
 let body='';
 if(k==='sellers'||k==='allsellers')body=sel.length?sel.map(s=>`<article class="pocard adpo"><div class="pohead"><button class="pouser" data-a="user" data-u="${s.user_id}">${av(s.user_id,36)}<span class="grow"><b>${esc(pname(s.user_id))}${vb(s.user_id)}</b><small>${ago(s.created_at)}</small></span></button>${k==='allsellers'?`<span class="ist ${s.status==='approved'?'s-active':'s-rejected'}">${s.status==='approved'?'გამყიდველი':'შეჩერებული'}</span>`:''}</div>
   <b>${esc(s.name)}</b>${s.city?`<span class="sub">${esc(s.city)}</span>`:''}${s.about?`<p class="pofacts">${esc(s.about)}</p>`:''}${s.note?`<p class="pofacts">შენიშვნა: ${esc(s.note)}</p>`:''}
   <div class="adquick">${s.status==='pending'?`<button class="btn" data-a="adshsel" data-u="${s.user_id}" data-s="approved">${ic('check')}დაშვება</button><button class="btn ghost" data-a="adshsel" data-u="${s.user_id}" data-s="rejected">${ic('x')}უარყოფა</button>`
    :s.status==='approved'?`<button class="btn ghost" data-a="adshsel" data-u="${s.user_id}" data-s="blocked">${ic('block')}შეჩერება</button>`:`<button class="btn ghost" data-a="adshsel" data-u="${s.user_id}" data-s="approved">${ic('check')}ისევ დაშვება</button>`}</div></article>`).join(''):empty(k==='sellers'?'ახალი განაცხადი არ არის':'გამყიდველები ჯერ არ არიან','');
 else if(k==='items')body=items.length?items.map(i=>`<article class="pocard adpo"><div class="pohead"><button class="pouser" data-a="user" data-u="${i.seller}">${av(i.seller,36)}<span class="grow"><b>${esc(pname(i.seller))}</b><small>${ago(i.updated_at)}${i.approved===false&&i.sold?' · ცვლილება':''}</small></span></button></div>
   ${(i.media||[]).length?`<div class="mgal adshgal">${i.media.map(m=>`<img src="${esc(mSm(m))}" alt="" loading="lazy">`).join('')}</div>`:''}
   <b>${esc(i.title)}</b><span class="sub">${shCoin(i.price)} · მარაგი ${i.stock}</span>${i.about?`<p class="pofacts">${esc(i.about)}</p>`:''}${i.delivery?`<p class="pofacts">მიწოდება: ${esc(i.delivery)}</p>`:''}
   <div class="adquick"><button class="btn" data-a="adshitem" data-id="${i.id}" data-ok="1">${ic('check')}დადასტურება</button><button class="btn ghost" data-a="adshitem" data-id="${i.id}" data-ok="0">${ic('x')}უარყოფა</button></div></article>`).join(''):empty('შესამოწმებელი პროდუქტი არ არის','');
 else body=disp.length?disp.map(o=>`<article class="pocard adpo"><div class="pohead"><b>${esc(o.title)}</b><small>${ago(o.created_at)}</small></div><b class="pogel">${shCoin(o.price)}</b>
   <p class="pofacts">მყიდველი: <button class="lnk" data-a="user" data-u="${o.buyer}">${esc(pname(o.buyer))}</button> · გამყიდველი: <button class="lnk" data-a="user" data-u="${o.seller}">${esc(pname(o.seller))}</button>${o.shipped_at?` · გაიგზავნა ${ago(o.shipped_at)}`:' · არ გაგზავნილა'}</p>
   <div class="pocopy"><span class="grow"><small>მიწოდება</small><span>${esc(o.delivery)}</span></span></div>${o.ship_note?`<p class="pofacts">გაგზავნა: ${esc(o.ship_note)}</p>`:''}<p class="pofacts"><b>პრობლემა:</b> ${esc(o.dispute||'')}</p>
   <div class="adquick"><button class="btn" data-a="adshres" data-id="${o.id}" data-r="1">${ic('x')}მყიდველს დაუბრუნე</button><button class="btn ghost" data-a="adshres" data-id="${o.id}" data-r="0">${ic('check')}გამყიდველს გადაუხადე</button></div></article>`).join(''):empty('დავები არ არის','');
 el.innerHTML=`<div class="chipsbar adtabs" role="group" aria-label="მაღაზია">${chip('sellers','განაცხადები',pend)}${chip('items','პროდუქტები',items.length)}${chip('disputes','დავები',disp.length)}${chip('allsellers','გამყიდველები')}</div><div class="polist2">${body}</div>`}
A.adshk=t=>{ADM.shk=t.dataset.k;adminTab()};
/* a short reason the other side will read */
function admReason(title,label,okLabel,fn,need){sheet(head(title)+`<form class="ph-body form" id="adrf"><label class="fld">${label}<textarea id="adr_t" rows="3" maxlength="200"></textarea></label><button class="btn">${okLabel}</button></form>`,'short');
 $('#adrf').onsubmit=async e=>{e.preventDefault();const v=$('#adr_t').value.trim();if(need&&v.length<3){toast('დაწერე მიზეზი');return}try{await fn(v||null);closeSheet();refreshStats();adminTab()}catch(x){toast(errMsg(x))}}}
A.adshsel=t=>{const u=t.dataset.u,s=t.dataset.s;if(s==='approved')return rpc('admin_shop_seller',{p_user:u,p_status:s,p_note:null}).then(()=>{toast('დაშვებულია');refreshStats();adminTab()}).catch(e=>toast(errMsg(e)));
 admReason(s==='blocked'?'გამყიდველის შეჩერება':'განაცხადის უარყოფა','მიზეზი (ადამიანი ნახავს)',s==='blocked'?'შეჩერება':'უარყოფა',v=>rpc('admin_shop_seller',{p_user:u,p_status:s,p_note:v}),true)};
A.adshitem=t=>{const id=+t.dataset.id;if(t.dataset.ok==='1')return rpc('admin_shop_item',{p_id:id,p_ok:true,p_note:null}).then(()=>{toast('გამოჩნდა მაღაზიაში');refreshStats();adminTab()}).catch(e=>toast(errMsg(e)));
 admReason('პროდუქტის უარყოფა','მიზეზი (გამყიდველი ნახავს)','უარყოფა',v=>rpc('admin_shop_item',{p_id:id,p_ok:false,p_note:v}),true)};
A.adshres=t=>{const id=+t.dataset.id,r=t.dataset.r==='1';admReason(r?'მონეტების დაბრუნება მყიდველზე':'გადახდა გამყიდველზე','გადაწყვეტილების მიზეზი (ორივე მხარე ნახავს)',r?'დაბრუნება':'გადახდა',v=>rpc('admin_shop_resolve',{p_order:id,p_refund:r,p_note:v}),true)};
