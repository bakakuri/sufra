/* Georgian kitchen: recipes with ingredients and steps, portions, a step-by-step cooking mode,
   ingredients straight into a party's "who brings what" list, and "I made it too" photos */
const RCAT=[['ცომეული','🥟',30],['ხორციანი','🍖',8],['ბოსტნეული','🥗',110],['წვნიანი','🍲',22],['სალათი','🥙',140],['ტკბილეული','🍯',40],['სოუსი','🫙',350],['სხვა','🍽️',260]];
const rcat=c=>RCAT.find(x=>x[0]===c)||RCAT[RCAT.length-1];
const RSEL='id,author,title,about,photo_url,category,region,servings,minutes,ingredients,steps,likes,cooks,created_at';
let RCP={cat:'',q:''};
const rcTime=m=>m>=60?`${Math.floor(m/60)} სთ${m%60?' '+m%60+' წთ':''}`:`${m} წთ`;
const rcHero=r=>r.photo_url?`<img src="${esc(r.photo_url)}" alt="" loading="lazy">`:`<span class="rcart" style="--h:${rcat(r.category)[2]}"><i>${rcat(r.category)[1]}</i></span>`;
function recipeCard(r){return `<button class="rcard" data-a="page" data-p="recipe" data-arg="${r.id}"><span class="rcimg">${rcHero(r)}<em>${ic('clock')}${rcTime(r.minutes)}</em></span><b>${esc(r.title)}</b><small>${esc(r.category)}${r.region?' · '+esc(r.region):''}</small><span class="rcst">${ic('heart')}${r.likes||0}<span class="sp"></span>${r.cooks?`${ic('camera')}${r.cooks}`:''}</span></button>`}
PG.recipes={r(){view.innerHTML=pgHead('ქართული სამზარეულო',`<button class="btn sm" data-a="recipenew">${ic('plus')}რეცეპტი</button>`)+`<form class="search rcsearch" id="rcf" role="search"><input class="field" id="rcq" type="search" placeholder="ძებნა: ხინკალი, ლობიო, ხაჭაპური…" value="${esc(RCP.q)}" aria-label="რეცეპტის ძებნა"></form>
 <div class="chipsbar" role="group" aria-label="კატეგორია"><button data-a="rccat" data-c="" aria-pressed="${!RCP.cat}">ყველა</button>${RCAT.map(([c,e])=>`<button data-a="rccat" data-c="${c}" aria-pressed="${RCP.cat===c}">${e} ${c}</button>`).join('')}</div><div id="rcb">${skel(2)}</div>`;
 $('#rcf').onsubmit=e=>{e.preventDefault();RCP.q=$('#rcq').value.trim();loadRecipes()};let t;$('#rcq').oninput=()=>{clearTimeout(t);t=setTimeout(()=>{RCP.q=$('#rcq').value.trim();loadRecipes()},350)};loadRecipes()}};
A.rccat=t=>{RCP.cat=t.dataset.c;$$('[data-a="rccat"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)));loadRecipes()};
async function loadRecipes(){const el=$('#rcb');if(!el)return;try{let b=sb.from('recipes').select(RSEL).order('likes',{ascending:false}).order('created_at',{ascending:false}).limit(80);if(RCP.cat)b=b.eq('category',RCP.cat);if(RCP.q)b=b.ilike('title','%'+RCP.q.replace(/[%_,()]/g,' ')+'%');
 const rows=await q(b);if(!el.isConnected)return;el.innerHTML=rows.length?`<div class="rcgrid">${rows.map(recipeCard).join('')}</div>`:empty('რეცეპტი ვერ მოიძებნა','დაამატე შენი და სხვებიც ნახავენ.','<button class="btn" data-a="recipenew">რეცეპტის დამატება</button>');staggerIn($$('.rcard',el).slice(0,8))}
 catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}

/* one recipe: portions scale the amounts */
let RC=null;
const FR={'½':.5,'¼':.25,'¾':.75,'⅓':1/3,'⅔':2/3};
const fmtQ=x=>{if(x>=10)return String(x>=100?Math.round(x/5)*5:Math.round(x));const whole=Math.floor(x),fr=x-whole,f=fr<.13?'':fr<.38?'¼':fr<.63?'½':fr<.88?'¾':'',n=fr>=.88?whole+1:whole;return n===0&&!f?(x>0?'⅛':'0'):(n||!f?String(n):'')+f};
const numQ=(a,b)=>(a?parseFloat(a.replace(',','.')):0)+(b?FR[b]:0);
function scaleQ(q,k){if(k===1)return q;q=String(q);let m=q.match(/^(\d+(?:[.,]\d+)?)\s*[–-]\s*(\d+(?:[.,]\d+)?)(\s*)(.*)$/);if(m)return fmtQ(numQ(m[1])*k)+'–'+fmtQ(numQ(m[2])*k)+(m[4]?m[3]||' ':'')+m[4];
 m=q.match(/^(\d+(?:[.,]\d+)?)?\s*([½¼¾⅓⅔])?(\s*)(.*)$/);if(!m||(!m[1]&&!m[2]))return q;return fmtQ(numQ(m[1],m[2])*k)+(m[4]?m[3]||' ':'')+m[4]}
PG.recipe={r(id){view.innerHTML=pgHead('რეცეპტი')+`<div id="rcp">${skel(2)}</div>`;loadRecipe(+id)}};
async function loadRecipe(id){const el=$('#rcp');try{const[r,lk,ck]=await Promise.all([q(sb.from('recipes').select(RSEL).eq('id',id).maybeSingle()),q(sb.from('recipe_likes').select('user_id').eq('recipe_id',id).eq('user_id',ME.id).maybeSingle()),q(sb.from('recipe_cooks').select('id,user_id,photo_url,note,created_at').eq('recipe_id',id).order('created_at',{ascending:false}).limit(30))]);
 if(!el||!el.isConnected)return;if(!r){el.innerHTML=empty('რეცეპტი ვერ მოიძებნა','შეიძლება წაშლილია.');return}
 await loadProfiles([r.author,...ck.map(c=>c.user_id)].filter(Boolean));RC={r,k:1,liked:!!lk,serv:r.servings};const h=$('.pghead h2');if(h)h.textContent=r.title;
 const mine=r.author===ME.id;
 el.innerHTML=`<div class="rchero">${rcHero(r)}</div><section class="rcbody"><h1>${esc(r.title)}</h1>
  <p class="rcby">${r.author?`<button class="pname" data-a="user" data-u="${r.author}">${av(r.author,22)}${esc(pname(r.author))}</button>`:`<span class="rcsys">${ic('book')}სუფრის რეცეპტები</span>`}</p>
  <div class="rcmeta"><span>${ic('clock')}${rcTime(r.minutes)}</span><span>${rcat(r.category)[1]} ${esc(r.category)}</span>${r.region?`<span>${ic('pin')}${esc(r.region)}</span>`:''}</div>
  ${r.about?`<p class="rcabout">${esc(r.about)}</p>`:''}
  <div class="pbtns"><button class="btn${RC.liked?'':' ghost'}" data-a="rclike" id="rclk">${ic('heart',RC.liked?'currentColor':'')}გემრიელია · <span>${r.likes||0}</span></button><button class="btn ghost" data-a="rccook">${ic('clips')}მზადება ნაბიჯ-ნაბიჯ</button><button class="btn ghost" data-a="rcevent">${ic('cal')}სუფრაზე წაღება</button><button class="ibtn sq" data-a="rcshare" aria-label="გაზიარება">${ic('share')}</button>${mine||isStaff()?`<button class="ibtn sq" data-a="rcmore" aria-label="მეტი">${ic('more')}</button>`:''}</div>
  <div class="rcsec"><div class="rcsh"><h3>ინგრედიენტები</h3><span class="sp"></span><div class="stepper" role="group" aria-label="პორციები"><button data-a="rcserv" data-d="-1" aria-label="ნაკლები">−</button><span id="rcsv">${RC.serv} პორცია</span><button data-a="rcserv" data-d="1" aria-label="მეტი">+</button></div></div><ul class="rcing" id="rcing"></ul></div>
  <div class="rcsec"><h3>მომზადება</h3><ol class="rcsteps">${r.steps.map(s=>`<li>${esc(s)}</li>`).join('')}</ol></div>
  <div class="rcsec"><div class="rcsh"><h3>გააკეთეს${ck.length?' · '+ck.length:''}</h3><span class="sp"></span><button class="btn sm" data-a="rcmade">${ic('camera')}მეც გავაკეთე</button></div>
   ${ck.length?`<div class="rccooks">${ck.map(c=>`<div class="rccook">${c.photo_url?`<button class="rccp" data-a="bigpicview" data-src="${esc(c.photo_url)}" aria-label="ფოტოს ნახვა"><img src="${esc(c.photo_url)}" alt="" loading="lazy"></button>`:''}<div><button class="pname" data-a="user" data-u="${c.user_id}">${av(c.user_id,24)}<b>${esc(pname(c.user_id))}</b></button>${c.note?`<p>${esc(c.note)}</p>`:''}<small>${ago(c.created_at)}</small></div></div>`).join('')}</div>`:'<p class="note">ჯერ არავის უჩვენებია. იყავი პირველი და ატვირთე შენი კერძის ფოტო.</p>'}</div></section>`;
 drawIng()}catch(e){if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
function drawIng(){const el=$('#rcing');if(!el||!RC)return;el.innerHTML=RC.r.ingredients.map(x=>`<li><label class="chk"><input type="checkbox"><span><b>${esc(x.n)}</b>${x.q?`<em>${esc(scaleQ(x.q,RC.k))}</em>`:''}</span></label></li>`).join('');const s=$('#rcsv');if(s)s.textContent=RC.serv+' პორცია'}
A.rcserv=t=>{if(!RC)return;RC.serv=Math.max(1,Math.min(40,RC.serv+(+t.dataset.d)));RC.k=RC.serv/RC.r.servings;drawIng()};
A.rclike=async t=>{if(!RC)return;const on=!RC.liked;RC.liked=on;RC.r.likes=Math.max(0,(RC.r.likes||0)+(on?1:-1));t.classList.toggle('ghost',!on);t.innerHTML=`${ic('heart',on?'currentColor':'')}გემრიელია · <span>${RC.r.likes}</span>`;if(on){pop(t);burst(t)}
 try{if(on)await q(sb.from('recipe_likes').insert({recipe_id:RC.r.id,user_id:ME.id}));else await q(sb.from('recipe_likes').delete().eq('recipe_id',RC.r.id).eq('user_id',ME.id))}catch(e){toast(errMsg(e))}};
A.rcshare=()=>{if(RC)shareLink(location.origin+'/#recipe-'+RC.r.id,RC.r.title)};
/* cooking mode: one step at a time in big letters, with a timer when the step names minutes */
A.rccook=()=>{if(!RC)return;const S2=RC.r.steps;let i=0,tm=null,left=0;
 const draw=()=>{const s=S2[i],m=s.match(/(\d+)(?:\s*[–-]\s*(\d+))?\s*(წუთ|საათ)/),mins=m?(m[3]==='საათ'?60:1)*(+m[2]||+m[1]):0;
  $('#ckb').innerHTML=`<div class="ckn">ნაბიჯი ${i+1} / ${S2.length}</div><p class="ckt">${esc(s)}</p>${mins?`<button class="btn ghost" data-a="cktimer" data-m="${mins}" id="cktb">${ic('timer')}${tm?'ტაიმერი: '+fmtLeft(left):'ტაიმერი · '+rcTime(mins)}</button>`:''}`;
  $('#ckp').disabled=i===0;$('#ckx').textContent=i===S2.length-1?'დასრულება':'შემდეგი'};
 const fmtLeft=s=>`${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}`;
 layer(lhead(esc(RC.r.title))+`<div class="ph-body ckbody" id="ckb"></div><div class="ph-foot"><button class="btn ghost" id="ckp">წინა</button><span class="sp"></span><button class="btn" id="ckx">შემდეგი</button></div>`,()=>{clearInterval(tm);tm=null;try{wl&&wl.release()}catch(e){}});
 let wl=null;try{navigator.wakeLock?.request('screen').then(x=>{wl=x}).catch(()=>{})}catch(e){}
 A.cktimer=t=>{if(tm){clearInterval(tm);tm=null;draw();return}left=(+t.dataset.m)*60;tm=setInterval(()=>{left--;const b=$('#cktb');if(b)b.innerHTML=`${ic('timer')}ტაიმერი: ${fmtLeft(Math.max(0,left))}`;if(left<=0){clearInterval(tm);tm=null;beep();toast('⏰ დრო ამოიწურა!');try{navigator.vibrate&&navigator.vibrate([300,150,300])}catch(e){}draw()}},1000);draw()};
 $('#ckp').onclick=()=>{if(i>0){i--;draw()}};$('#ckx').onclick=()=>{if(i<S2.length-1){i++;draw()}else{closeLayer();toast('გემრიელად მიირთვით! 🍽️')}};draw()};
function beep(){try{const C=window.AudioContext||window.webkitAudioContext,a=new C(),o=a.createOscillator(),g=a.createGain();o.frequency.value=880;o.connect(g);g.connect(a.destination);g.gain.setValueAtTime(.3,a.currentTime);g.gain.exponentialRampToValueAtTime(.001,a.currentTime+1.2);o.start();o.stop(a.currentTime+1.2)}catch(e){}}
/* the ingredients go to a party's "who brings what" list */
A.rcevent=async()=>{if(!RC)return;let evs=[];try{const now=new Date().toISOString();const[own,rs]=await Promise.all([q(sb.from('events').select('id,title,starts_at').eq('host',ME.id).gte('starts_at',now)),q(sb.from('event_rsvps').select('event_id').eq('user_id',ME.id).eq('status','yes'))]);
  const ids=rs.map(x=>x.event_id).filter(id=>!own.some(e=>e.id===id));const other=ids.length?await q(sb.from('events').select('id,title,starts_at').in('id',ids).gte('starts_at',now)):[];evs=[...own,...other].sort((a,b)=>a.starts_at.localeCompare(b.starts_at))}catch(e){}
 if(!evs.length){sheet(head('სუფრაზე წაღება')+`<div class="ph-body"><p>მომავალი ღონისძიება არ გაქვს. შექმენი სუფრა და ინგრედიენტები „ვინ რა მოიტანს“ სიაში ჩაჯდება.</p><button class="btn" data-a="page" data-p="evnew">ღონისძიების შექმნა</button></div>`,'short');return}
 sheet(head('სუფრაზე წაღება')+`<form class="ph-body" id="rcef"><label class="fld">ღონისძიება<select id="rce">${evs.map(e=>`<option value="${e.id}">${esc(e.title)} · ${fdate(e.starts_at)}</option>`).join('')}</select></label><p class="note">მონიშნული ინგრედიენტები ჩაჯდება „ვინ რა მოიტანს“ სიაში. სტუმრები თავად აიღებენ, ვინ რას მოიტანს.</p>
  <div class="rcpick">${RC.r.ingredients.map((x,i)=>`<label class="chk"><input type="checkbox" data-i="${i}" checked><span>${esc(x.n)}${x.q?' · '+esc(scaleQ(x.q,RC.k)):''}</span></label>`).join('')}</div><button class="btn">${ic('check')}დამატება</button></form>`);
 $('#rcef').onsubmit=async e=>{e.preventDefault();const ev=+$('#rce').value,sel=$$('.rcpick input:checked').map(c=>RC.r.ingredients[+c.dataset.i]);if(!sel.length){toast('მონიშნე ერთი მაინც');return}
  try{await q(sb.from('event_items').insert(sel.map(x=>({event_id:ev,name:(x.n+(x.q?' ('+scaleQ(x.q,RC.k)+')':'')).slice(0,80),added_by:ME.id}))));closeSheet();toast(`${sel.length} ინგრედიენტი დაემატა სიაში`);openPage('event',ev,['recipe',RC.r.id])}catch(x){toast(errMsg(x))}}};
/* "I made it too": a photo and a few words */
A.rcmade=()=>{if(!RC)return;const st={url:null};
 sheet(head('მეც გავაკეთე')+`<form class="ph-body" id="rcmf">${picField('rcm_pic',null,'შენი კერძის ფოტო','არასავალდებულო, მაგრამ ყველას აინტერესებს')}<label class="fld">რამდენიმე სიტყვა<textarea id="rcm_n" maxlength="300" rows="3" placeholder="მაგ. ცოტა მეტი ნიორი ჩავამატე და ძალიან კარგი გამოვიდა"></textarea></label><button class="btn" id="rcm_ok">${ic('check')}გაზიარება</button></form>`);
 bindPic('rcm_pic',st,'კერძის ფოტო');
 $('#rcmf').onsubmit=async e=>{e.preventDefault();const b=$('#rcm_ok');b.disabled=true;try{if(st.p)await st.p;await q(sb.from('recipe_cooks').insert({recipe_id:RC.r.id,user_id:ME.id,photo_url:st.url||null,note:$('#rcm_n').value.trim()}));closeSheet();toast('გაზიარდა. ყოჩაღ! 👏');confetti();loadRecipe(RC.r.id)}catch(x){toast(errMsg(x));b.disabled=false}}};
A.rcmore=()=>{if(!RC)return;sheet(head('რეცეპტი')+`<div class="reasons"><button data-a="recipenew" data-id="${RC.r.id}">${ic('edit')}რედაქტირება</button><button data-a="rcdel" class="warnbtn">${ic('trash')}წაშლა</button></div>`,'short')};
A.rcdel=()=>{if(!RC)return;const id=RC.r.id;confirmSheet('რეცეპტის წაშლა','რეცეპტი და მისი ფოტოები წაიშლება.','წაშლა',async()=>{await q(sb.from('recipes').delete().eq('id',id));openPage('recipes')},true)};
/* writing a recipe */
A.recipenew=async t=>{const id=t&&t.dataset&&+t.dataset.id;let r=null;if(id){try{r=await q(sb.from('recipes').select(RSEL).eq('id',id).single())}catch(e){toast(errMsg(e));return}}
 r=r||{title:'',about:'',category:'ხორციანი',region:'',servings:4,minutes:60,ingredients:[{n:'',q:''},{n:'',q:''},{n:'',q:''}],steps:['','']};const st={url:r.photo_url||null};
 const ingRow=x=>`<div class="rcrow"><input class="field sq" data-k="n" maxlength="60" placeholder="ინგრედიენტი" value="${esc(x.n||'')}"><input class="field sq" data-k="q" maxlength="30" placeholder="რაოდენობა" value="${esc(x.q||'')}"><button type="button" class="ibtn sm" data-rm aria-label="წაშლა">${ic('x')}</button></div>`;
 const stepRow=(x,i)=>`<div class="rcrow st"><span class="rcn">${i+1}</span><textarea class="field sq" maxlength="600" rows="2" placeholder="რა უნდა გაკეთდეს">${esc(x||'')}</textarea><button type="button" class="ibtn sm" data-rm aria-label="წაშლა">${ic('x')}</button></div>`;
 sheet(head(id?'რეცეპტის რედაქტირება':'ახალი რეცეპტი')+`<form class="ph-body" id="rnf">${picField('rn_pic',st.url,'კერძის ფოტო','ლამაზი ფოტო რეცეპტს უფრო მისაწვდომს ხდის')}
  <label class="fld">სახელი<input id="rn_t" maxlength="80" required value="${esc(r.title)}" placeholder="მაგ. მეგრული ხაჭაპური"></label>
  <div class="frow"><label class="fld">კატეგორია<select id="rn_c">${RCAT.map(([c,e])=>`<option${r.category===c?' selected':''} value="${c}">${e} ${c}</option>`).join('')}</select></label><label class="fld">კუთხე<input id="rn_r" maxlength="40" value="${esc(r.region)}" placeholder="მაგ. სამეგრელო"></label></div>
  <div class="frow"><label class="fld">დრო (წუთი)<input id="rn_m" type="number" min="1" max="2880" value="${r.minutes}"></label><label class="fld">პორცია<input id="rn_s" type="number" min="1" max="40" value="${r.servings}"></label></div>
  <label class="fld">მოკლედ კერძზე<textarea id="rn_a" maxlength="500" rows="2">${esc(r.about)}</textarea></label>
  <div class="fld">ინგრედიენტები<div class="rcrows" id="rn_i">${r.ingredients.map(ingRow).join('')}</div><button type="button" class="btn sm ghost" id="rn_ia">${ic('plus')}ინგრედიენტი</button></div>
  <div class="fld">მომზადება<div class="rcrows" id="rn_st">${r.steps.map(stepRow).join('')}</div><button type="button" class="btn sm ghost" id="rn_sa">${ic('plus')}ნაბიჯი</button></div>
  <button class="btn" id="rn_ok">${ic('check')}${id?'შენახვა':'გამოქვეყნება'}</button></form>`);
 bindPic('rn_pic',st,'კერძის ფოტო');
 const renum=()=>$$('#rn_st .rcn').forEach((n,i)=>{n.textContent=i+1});
 $('#rn_ia').onclick=()=>$('#rn_i').insertAdjacentHTML('beforeend',ingRow({}));$('#rn_sa').onclick=()=>{$('#rn_st').insertAdjacentHTML('beforeend',stepRow('',$$('#rn_st .rcrow').length));renum()};
 $('#rnf').addEventListener('click',e=>{const x=e.target.closest('[data-rm]');if(x){x.closest('.rcrow').remove();renum()}});
 $('#rnf').onsubmit=async e=>{e.preventDefault();const b=$('#rn_ok');const ing=$$('#rn_i .rcrow').map(r=>({n:$('[data-k=n]',r).value.trim(),q:$('[data-k=q]',r).value.trim()})).filter(x=>x.n),steps=$$('#rn_st textarea').map(x=>x.value.trim()).filter(Boolean);
  const title=$('#rn_t').value.trim();if(title.length<2){toast('ჩაწერე კერძის სახელი');return}if(!ing.length){toast('დაამატე ერთი ინგრედიენტი მაინც');return}if(!steps.length){toast('დაწერე ერთი ნაბიჯი მაინც');return}
  b.disabled=true;try{if(st.p)await st.p;const row={title,category:$('#rn_c').value,region:$('#rn_r').value.trim(),minutes:Math.max(1,Math.min(2880,+$('#rn_m').value||60)),servings:Math.max(1,Math.min(40,+$('#rn_s').value||4)),about:$('#rn_a').value.trim(),photo_url:st.url||null,ingredients:ing,steps};
   let rid=id;if(id)await q(sb.from('recipes').update(row).eq('id',id));else rid=(await q(sb.from('recipes').insert(Object.assign({author:ME.id},row)).select('id').single())).id;
   closeSheet();toast(id?'შენახულია':'რეცეპტი გამოქვეყნდა');if(!id)checkBadges(true);openPage('recipe',rid,['recipes'])}catch(x){toast(errMsg(x));b.disabled=false}}};
