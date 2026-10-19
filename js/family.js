/* family tree and surnames */
const KREL=[['parent','მშობელი'],['child','შვილი'],['sibling','და ან ძმა'],['spouse','მეუღლე']];
const GEN_TXT={'-3':'დიდი ბებია-ბაბუები','-2':'ბებია-ბაბუები','-1':'მშობლები','0':'თაობა','1':'შვილები','2':'შვილიშვილები','3':'შვილთაშვილები'};
/* the Georgian kinship word for a chain of relations from the tree owner, e.g. [parent(f), sibling(f)] → დეიდა */
function kinLabel(chain,ownerSex){const r=chain.map(c=>c.rel).join('>'),last=chain[chain.length-1]||{},sx=last.sex,f=sx==='f',m=sx==='m',c0=chain[0]||{},c1=chain[1]||{};
 const pick=(a,b,c)=>f?a:m?b:c;
 switch(r){
  case 'parent':return pick('დედა','მამა','მშობელი');
  case 'parent>parent':return pick('ბებია','ბაბუა','ბებია ან ბაბუა');
  case 'parent>parent>parent':return pick('დიდი ბებია','დიდი ბაბუა','წინაპარი');
  case 'parent>parent>parent>parent':return 'წინაპარი';
  case 'child':return pick('ქალიშვილი','ვაჟი','შვილი');
  case 'child>child':return 'შვილიშვილი';
  case 'child>child>child':return 'შვილთაშვილი';
  case 'sibling':return pick('და','ძმა','და ან ძმა');
  case 'spouse':return ownerSex==='m'?'ცოლი':ownerSex==='f'?'ქმარი':'მეუღლე';
  case 'parent>sibling':return m?'ბიძა':f?(c0.sex==='f'?'დეიდა':c0.sex==='m'?'მამიდა':'დეიდა ან მამიდა'):'მშობლის და-ძმა';
  case 'parent>sibling>child':return c1.sex==='m'?'ბიძაშვილი':c1.sex==='f'?(c0.sex==='f'?'დეიდაშვილი':'მამიდაშვილი'):'ბიძაშვილი';
  case 'sibling>child':return c0.sex==='f'?'დისშვილი':c0.sex==='m'?'ძმისშვილი':'ძმისშვილი ან დისშვილი';
  case 'child>spouse':case 'sibling>spouse':return pick('რძალი','სიძე','მეუღლე');
  case 'spouse>parent':return ownerSex==='m'?pick('სიდედრი','სიმამრი','სიდედრი ან სიმამრი'):ownerSex==='f'?pick('დედამთილი','მამამთილი','დედამთილი ან მამამთილი'):'მეუღლის მშობელი';
  case 'spouse>sibling':return ownerSex==='m'?pick('ცოლისდა','ცოლისძმა','ცოლის და-ძმა'):ownerSex==='f'?pick('მული','მაზლი','ქმრის და-ძმა'):'მეუღლის და-ძმა';
  case 'parent>spouse':return pick('დედინაცვალი','მამინაცვალი','მშობლის მეუღლე');
  case 'parent>child':return pick('და','ძმა','და ან ძმა');
  default:return 'ნათესავი'}}
const GDELTA={parent:-1,child:1,sibling:0,spouse:0};

PG.tree={r(uid){uid=uid||ME.id;const mine=uid===ME.id;view.innerHTML=pgHead('ოჯახის ხე',mine?`<button class="btn sm" data-a="kinadd">${ic('plus')}დამატება</button>`:'')+`<div id="trb">${skel(2)}</div>`;loadTree(uid)}};
async function loadTree(uid){const el=$('#trb');const mine=uid===ME.id;let rows=[],pend=[],owner;
 try{[rows,pend]=await Promise.all([q(sb.from('kin').select('id,owner,anchor,relative,name,relation,sex,born,died,status,created_at').eq('owner',uid).order('id').limit(200)),mine?q(sb.from('kin').select('id,owner,relation,created_at').eq('relative',ME.id).eq('status','pending')):Promise.resolve([])]);
  await loadProfiles([uid,...rows.map(r=>r.relative),...pend.map(p=>p.owner)]);owner=uid===ME.id?ME:prof(uid)}catch(e){if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e));return}
 if(!el||!el.isConnected)return;const h=$('.pghead h2');if(h&&!mine)h.textContent='ოჯახის ხე · '+String(owner.name).split(' ')[0];
 /* nodes: the owner at generation 0, every row hangs off its anchor (or the owner) */
 const N=new Map();N.set('r',{key:'r',root:true,gen:0,chain:[],uid,name:owner.name,sex:owner.gender==='f'?'f':owner.gender==='m'?'m':null});
 const ownerSex=N.get('r').sex;
 rows.forEach(r=>{const par=N.get(r.anchor?'k'+r.anchor:'r');if(!par)return;const sex=r.sex||(r.relative?(g=>g==='f'?'f':g==='m'?'m':null)(prof(r.relative).gender):null);
  N.set('k'+r.id,{key:'k'+r.id,row:r,parent:par.key,gen:par.gen+GDELTA[r.relation],chain:[...par.chain,{rel:r.relation,sex}],uid:r.relative,name:r.relative?pname(r.relative):r.name,sex})});
 N.forEach(n=>{if(!n.root)n.label=kinLabel(n.chain,ownerSex)});
 const gens=[...new Set([...N.values()].map(n=>n.gen))].sort((a,b)=>a-b);
 const order=n=>{const path=[];let x=n;while(x&&!x.root){path.unshift(x.row.id);x=N.get(x.parent)}return path};
 const byGen=g=>[...N.values()].filter(n=>n.gen===g).sort((a,b)=>{if(a.root)return b.row?.relation==='sibling'?1:-1;if(b.root)return a.row?.relation==='sibling'?-1:1;const pa=order(a),pb=order(b);for(let i=0;i<Math.max(pa.length,pb.length);i++){if(pa[i]!==pb[i])return (pa[i]??-1)-(pb[i]??-1)}return 0});
 const nodeHTML=n=>{const r=n.row,yrs=r&&(r.born||r.died)?`${r.born||'?'}${r.died?'–'+r.died:''}`:'',pending=r&&r.status==='pending';
  return `<button class="knode${n.root?' root':''}${pending?' pend':''}${r&&r.died?' gone':''}" data-a="kinnode" data-node="${n.key}" data-owner="${uid}">${n.uid?av(n.uid,48):`<span class="av" style="--s:48px;--h:${n.sex==='f'?330:n.sex==='m'?210:40}">${esc(String(n.name||'?').trim()[0]||'?')}</span>`}<b>${esc(String(n.name||'').split(' ').slice(0,2).join(' '))}</b><small>${n.root?(mine?'მე':''):esc(n.label)}${yrs?' · '+yrs:''}${pending?' · ელოდება':''}</small></button>`};
 S.tree={uid,N,mine};
 el.innerHTML=(pend.length?`<section class="kpend"><h3 class="sec2" style="padding:0 0 6px">ნათესაობის მოთხოვნები</h3>${pend.map(p=>`<div class="row">${av(p.owner,40)}<span class="grow"><b>${esc(pname(p.owner))}</b><span class="sub">მის ოჯახის ხეში: ${esc(kinLabel([{rel:p.relation,sex:ME.gender==='f'?'f':ME.gender==='m'?'m':null}],(g=>g==='f'?'f':g==='m'?'m':null)(prof(p.owner).gender)))}</span></span><button class="btn sm" data-a="kinok" data-k="${p.id}">დადასტურება</button><button class="btn sm ghost" data-a="kinno" data-k="${p.id}" aria-label="უარყოფა">${ic('x')}</button></div>`).join('')}</section>`:'')
  +(N.size<2&&!mine?empty('ოჯახის ხე ჯერ ცარიელია'):'')
  +`<div class="ktree" id="ktree"><div class="ktin" id="ktin"><svg class="kedges" id="kedges" aria-hidden="true"></svg>${gens.map(g=>`<div class="kgen"><span class="kgl">${g===0&&mine?'მე და ჩემი თაობა':GEN_TXT[g]||(g<0?'წინაპრები':'შთამომავლები')}</span><div class="knodes">${byGen(g).map(nodeHTML).join('')}</div></div>`).join('')}</div></div>`
  +(mine?`<div class="row2" style="padding:8px 16px 4px;justify-content:flex-start"><button class="btn sm ghost" data-a="kinadd" data-anchor="">${ic('plus')}ნათესავის დამატება</button><button class="btn sm ghost" data-a="surname" data-s="${esc(ME.surname||'')}">${ic('users')}ჩემი გვარი</button></div><p class="note" style="padding:4px 16px 24px">შეეხე ადამიანს და დაამატე მისი მშობელი, შვილი ან მეუღლე. სუფრაზე მყოფ ნათესავს მოთხოვნა მიუვა და დადასტურების შემდეგ ხეში გამოჩნდება. ხეს ხედავენ შენი მეგობრები და ნათესავები.</p>`:'');
 requestAnimationFrame(drawEdges)}
function drawEdges(){const T=S.tree,box=$('#ktin'),svg=$('#kedges');if(!T||!box||!svg)return;const br=box.getBoundingClientRect();svg.setAttribute('width',box.scrollWidth);svg.setAttribute('height',box.scrollHeight);
 const pos=k=>{const e=box.querySelector(`[data-node="${k}"]`);if(!e)return null;const r=e.getBoundingClientRect();return{x:r.left-br.left+r.width/2,top:r.top-br.top,bot:r.bottom-br.top,l:r.left-br.left,r:r.right-br.left,mid:r.top-br.top+r.height/2}};
 let d='',dd='';T.N.forEach(n=>{if(n.root)return;const a=pos(n.parent),b=pos(n.key);if(!a||!b)return;const rel=n.row.relation;
  if(rel==='parent'){const y=(b.bot+a.top)/2;d+=`M${a.x} ${a.top}V${y}H${b.x}V${b.bot}`}
  else if(rel==='child'){const y=(a.bot+b.top)/2;d+=`M${a.x} ${a.bot}V${y}H${b.x}V${b.top}`}
  else if(rel==='spouse'){const L=a.x<b.x?a:b,R=a.x<b.x?b:a;dd+=`M${L.r} ${L.mid}H${R.l}`}
  else{const y=Math.min(a.top,b.top)-6;dd+=`M${a.x} ${a.top}V${y}H${b.x}V${b.top}`}});
 svg.innerHTML=`<path d="${d}" class="ke"/><path d="${dd}" class="ke dash"/>`}
window.addEventListener('resize',()=>{if(S.page?.id==='tree')drawEdges()});
A.kinnode=t=>{const T=S.tree,n=T&&T.N.get(t.dataset.node);if(!n)return;const r=n.row,canAdd=T.mine&&(n.root||!r.relative);
 sheet(head(esc(n.name||''))+`<div class="ph-body">${n.root?'':`<p class="muted">${esc(n.label)}${r.born||r.died?` · ${r.born||'?'}${r.died?'–'+r.died:''}`:''}${r.status==='pending'?' · ელოდება დადასტურებას':''}</p>`}</div><div class="reasons">
 ${n.uid&&n.uid!==ME.id?`<button data-a="user" data-u="${n.uid}">${ic('user')} პროფილი</button><button data-a="page" data-p="tree" data-arg="${n.uid}">${ic('tree')} მისი ოჯახის ხე</button>`:''}
 ${canAdd?KREL.map(([k,l])=>`<button data-a="kinadd" data-anchor="${n.root?'':r.id}" data-rel="${k}">${ic('plus')} ${n.root?'ჩემი':'მისი'} ${l}</button>`).join(''):''}
 ${T.mine&&r&&!r.relative?`<button data-a="kinedit" data-k="${r.id}">${ic('edit')} რედაქტირება</button>`:''}${T.mine&&r?`<button class="warnbtn" data-a="kindel" data-k="${r.id}">${ic('trash')} ხიდან ამოღება</button>`:''}</div>`,'short')};
A.kinadd=t=>{const anchor=t&&t.dataset&&t.dataset.anchor?+t.dataset.anchor:null;let rel=(t&&t.dataset&&t.dataset.rel)||'parent',who=anchor?'name':(t&&t.dataset&&t.dataset.u?'user':'name'),uid=t&&t.dataset&&t.dataset.u||null;
 const an=anchor&&S.tree?S.tree.N.get('k'+anchor):null;
 sheet(head(an?`${esc(an.name)} · ნათესავი`:'ნათესავის დამატება')+`<div class="ph-body"><div class="seg flat" role="group" aria-label="ვინ არის">${KREL.map(([k,l])=>`<button type="button" data-kr="${k}" aria-pressed="${k===rel}">${l}</button>`).join('')}</div>
  ${anchor?'':`<div class="seg flat" role="group" aria-label="სუფრაზეა?"><button type="button" data-kw="user" aria-pressed="${who==='user'}">სუფრაზეა</button><button type="button" data-kw="name" aria-pressed="${who==='name'}">სახელით</button></div>`}
  <div id="kw_user"${who==='user'?'':' hidden'}><p class="hint" style="padding:0">აირჩიე მეგობრებიდან. მას მოთხოვნა მიუვა.</p><div class="kfr">${[...FRIENDS].map(id=>`<label class="row pick"><input type="radio" name="kfr" value="${id}"${id===uid?' checked':''}>${av(id,36)}<span class="grow"><b>${esc(pname(id))}</b></span></label>`).join('')||'<p class="muted">მეგობრები ჯერ არ გყავს.</p>'}</div></div>
  <div id="kw_name"${who==='name'?'':' hidden'}><label class="fld">სახელი და გვარი<input id="kn_n" maxlength="60" placeholder="მაგ. ვახტანგ ბერიძე"></label><div class="seg flat" role="group" aria-label="სქესი"><button type="button" data-ks="f" aria-pressed="false">ქალი</button><button type="button" data-ks="m" aria-pressed="false">კაცი</button></div>
  <div class="frow"><label class="fld">დაბადების წელი<input id="kn_b" type="number" min="1000" max="2100" inputmode="numeric"></label><label class="fld">გარდაცვალების წელი<input id="kn_d" type="number" min="1000" max="2100" inputmode="numeric" placeholder="თუ აღარ არის"></label></div></div></div>
  <div class="ph-foot"><span class="sp"></span><button class="btn" id="kn_ok">დამატება</button></div>`);
 let sex=null;
 $$('[data-kr]').forEach(b=>b.onclick=()=>{rel=b.dataset.kr;$$('[data-kr]').forEach(z=>z.setAttribute('aria-pressed',String(z===b)))});
 $$('[data-kw]').forEach(b=>b.onclick=()=>{who=b.dataset.kw;$$('[data-kw]').forEach(z=>z.setAttribute('aria-pressed',String(z===b)));$('#kw_user').hidden=who!=='user';$('#kw_name').hidden=who!=='name'});
 $$('[data-ks]').forEach(b=>b.onclick=()=>{sex=b.dataset.ks;$$('[data-ks]').forEach(z=>z.setAttribute('aria-pressed',String(z===b)))});
 $('#kn_ok').onclick=async()=>{const b=$('#kn_ok');let row={owner:ME.id,relation:rel,anchor:anchor||null};
  if(who==='user'){const sel=$('input[name="kfr"]:checked');if(!sel){toast('აირჩიე მეგობარი');return}Object.assign(row,{relative:sel.value})}
  else{const n=$('#kn_n').value.trim();if(n.length<2){toast('ჩაწერე სახელი');return}const y=v=>{const x=parseInt(v,10);return x>=1000&&x<=2100?x:null};Object.assign(row,{name:n,sex,born:y($('#kn_b').value),died:y($('#kn_d').value)})}
  b.disabled=true;try{await q(sb.from('kin').insert(row));closeSheet();toast(row.relative?'მოთხოვნა გაიგზავნა':'დაემატა');openPage('tree',undefined,null,true)}catch(e){toast(/duplicate/i.test(e.message)?'ეს ადამიანი უკვე შენს ხეშია':/too_many/.test(e.message)?'ხეში მაქსიმუმ 200 ადამიანია':errMsg(e));b.disabled=false}}};
A.kinedit=t=>{const n=S.tree.N.get('k'+t.dataset.k),r=n.row;sheet(head('რედაქტირება')+`<div class="ph-body"><label class="fld">სახელი და გვარი<input id="ke_n" maxlength="60" value="${esc(r.name)}"></label><div class="seg flat" role="group" aria-label="სქესი"><button type="button" data-ks="f" aria-pressed="${r.sex==='f'}">ქალი</button><button type="button" data-ks="m" aria-pressed="${r.sex==='m'}">კაცი</button></div><div class="frow"><label class="fld">დაბადების წელი<input id="ke_b" type="number" value="${r.born||''}"></label><label class="fld">გარდაცვალების წელი<input id="ke_d" type="number" value="${r.died||''}"></label></div></div><div class="ph-foot"><span class="sp"></span><button class="btn" id="ke_ok">შენახვა</button></div>`,'short');
 let sex=r.sex;$$('[data-ks]').forEach(b=>b.onclick=()=>{sex=b.dataset.ks;$$('[data-ks]').forEach(z=>z.setAttribute('aria-pressed',String(z===b)))});
 $('#ke_ok').onclick=async()=>{const y=v=>{const x=parseInt(v,10);return x>=1000&&x<=2100?x:null};try{await q(sb.from('kin').update({name:$('#ke_n').value.trim()||r.name,sex,born:y($('#ke_b').value),died:y($('#ke_d').value)}).eq('id',r.id));closeSheet();loadTree(ME.id)}catch(e){toast(errMsg(e))}}};
A.kindel=t=>{const id=+t.dataset.k;confirmSheet('ხიდან ამოღება','ამოიშლება ეს ადამიანი და ყველა, ვინც მასზეა მიბმული.','ამოღება',async()=>{await q(sb.from('kin').delete().eq('id',id));loadTree(ME.id)},true)};
A.kinok=async t=>{try{await rpc('respond_kin',{p_id:+t.dataset.k,p_accept:true});toast('ნათესაობა დადასტურდა');confetti();loadTree(ME.id)}catch(e){toast(errMsg(e))}};
A.kinno=async t=>{try{await rpc('respond_kin',{p_id:+t.dataset.k,p_accept:false});loadTree(ME.id)}catch(e){toast(errMsg(e))}};
A.tree=t=>openPage('tree',t?.dataset?.u&&t.dataset.u!==ME.id?t.dataset.u:undefined);

/* surnames */
const lastWord=n=>{const w=String(n||'').trim().split(/\s+/);return w.length>1?w[w.length-1]:''};
A.surname=t=>{const s=(t&&t.dataset&&t.dataset.s)||ME.surname;if(s)openPage('surname',s);else A.setsurname()};
A.setsurname=()=>{sheet(head('ჩემი გვარი')+`<div class="ph-body"><label class="fld">გვარი<input id="sn_v" maxlength="40" value="${esc(ME.surname||lastWord(ME.name))}" placeholder="მაგ. ბერიძე"></label><p class="note">გვარით გაერთიანდებიან ერთი გვარის ადამიანები: საერთო ჯგუფი, ისტორია და ნათესავები.</p></div><div class="ph-foot"><span class="sp"></span><button class="btn" id="sn_ok">შენახვა</button></div>`,'short');
 $('#sn_ok').onclick=async()=>{const v=$('#sn_v').value.trim().replace(/\s+/g,' ');if(v.length<2){toast('ჩაწერე გვარი');return}try{await q(sb.from('profiles').update({surname:v}).eq('id',ME.id));ME.surname=v;closeSheet();openPage('surname',v)}catch(e){toast(errMsg(e))}}};
PG.surname={r(s){s=String(s||'').trim();view.innerHTML=pgHead('გვარი · '+esc(s))+`<div id="snb">${skel(2)}</div>`;loadSurname(s)}};
async function loadSurname(s){const el=$('#snb');try{const[people,grp]=await Promise.all([q(sb.from('profiles').select(PCOLS,{count:'exact'}).eq('surname',s).eq('onboarded',true).order('created_at').limit(80)),q(sb.from('groups').select('id,name').eq('place_key','surname:'+s.toLowerCase()).maybeSingle())]);
 people.forEach(p=>PC.set(p.id,p));if(!el||!el.isConnected)return;const mine=ME.surname===s;
 el.innerHTML=`<section class="snhero"><span class="snbig">${esc(s[0]||'?')}</span><div class="grow"><h2>${esc(s)}</h2><span class="sub">${people.length} ადამიანი სუფრაზე</span></div></section>
 <div class="pbtns" style="padding:0 16px 8px">${mine?`<button class="btn" data-a="snjoin" data-new="${grp?0:1}">${ic('users')}${grp?'გვარის ჯგუფი':'გვარის ჯგუფის შექმნა'}</button>`:grp?`<button class="btn" data-a="group" data-id="${grp.id}">${ic('users')}გვარის ჯგუფი</button>`:''}<button class="btn ghost" data-a="tree">${ic('tree')}ჩემი ოჯახის ხე</button>${mine?`<button class="btn ghost" data-a="setsurname">${ic('edit')}გვარის შეცვლა</button>`:ME.surname?'':`<button class="btn ghost" data-a="setsurname">${ic('edit')}ჩემი გვარის მითითება</button>`}</div>
 <h3 class="sec2">ამ გვარის ადამიანები</h3><div class="list">${people.map(personRow).join('')||'<p class="muted">ჯერ არავინ.</p>'}</div>`}catch(e){if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
A.snjoin=async t=>{if(t?.dataset?.new!=='1'){try{const g=await rpc('join_surname_group');openPage('group',g,['surname',ME.surname])}catch(e){toast(errMsg(e))}return}
 const st={url:null};sheet(head('გვარის ჯგუფის შექმნა')+`<div class="ph-body">${picField('sn_pic',null,'ჯგუფის სურათი','მაგ. ძველი ოჯახური ფოტო. შეგიძლია მერეც დაამატო')}<p class="note">ჯგუფი „გვარი · ${esc(ME.surname||'')}“ ღია იქნება ამ გვარის ყველა ადამიანისთვის. შენ იქნები მისი მფლობელი.</p></div><div class="ph-foot"><span class="sp"></span><button class="btn" id="sn_ok">შექმნა</button></div>`,'short');bindPic('sn_pic',st,'ჯგუფის სურათი');
 $('#sn_ok').onclick=async()=>{const b=$('#sn_ok');b.disabled=true;try{if(st.p)await st.p;const g=await rpc('join_surname_group');if(st.url)await sb.from('groups').update({avatar_url:st.url}).eq('id',g).eq('owner',ME.id);closeSheet();toast('ჯგუფი შეიქმნა');openPage('group',g,['surname',ME.surname])}catch(e){toast(errMsg(e));b.disabled=false}}};
