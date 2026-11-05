/* study: the study tab, schools and universities on the profile with the classmates and coursemates who share them,
   the lecture timetable, exams and assignments, notes (posts tagged #კონსპექტი) and study tips (posts tagged #რჩევა).
   The timetable, the deadlines and the education live in the database once its tables exist (lessons, deadlines, profiles.edu);
   until then they are kept on this phone, and finding classmates waits for the database. */
const KUR={db:{},cache:{}};
const kuMissing=e=>{const c=String(e&&e.code||''),m=String(e&&e.message||'');return ['42P01','PGRST205','42703','PGRST204','PGRST200'].includes(c)||/does not exist|schema cache|Could not find/i.test(m)};
const kuKey=k=>'ku:'+k+':'+(ME&&ME.id||'');
const kuSlug=s=>String(s||'').toLowerCase().replace(/[^a-z0-9ა-ჿ]+/g,'-').replace(/^-+|-+$/g,'').slice(0,60);
const pad2=n=>String(n).padStart(2,'0');
const kuDay=(d=new Date())=>(d.getDay()+6)%7+1;
const KDAYS=['ორშ','სამ','ოთხ','ხუთ','პარ','შაბ','კვ'];
const KDAYL=['ორშაბათი','სამშაბათი','ოთხშაბათი','ხუთშაბათი','პარასკევი','შაბათი','კვირა'];
const isoWeek=d=>{const t=new Date(Date.UTC(d.getFullYear(),d.getMonth(),d.getDate()));const n=t.getUTCDay()||7;t.setUTCDate(t.getUTCDate()+4-n);const y=new Date(Date.UTC(t.getUTCFullYear(),0,1));return Math.ceil(((t-y)/864e5+1)/7)};
const weekOk=(l,d=new Date())=>!l.weeks||l.weeks==='all'||(isoWeek(d)%2===1)===(l.weeks==='odd');
const hm=t=>String(t||'').slice(0,5);
const mins=t=>{const[a,b]=hm(t).split(':').map(Number);return a*60+(b||0)};

/* ---------- storage: the database when the table is there, otherwise this phone ---------- */
async function kuList(kind){
 if(KUR.db[kind]!==false){try{const rows=await q(sb.from(kind).select('*').limit(500));KUR.db[kind]=true;return (store.get(kuKey(kind),[])||[]).length?kuLift(kind,rows):rows}catch(e){if(!kuMissing(e))throw e;KUR.db[kind]=false}}
 return (store.get(kuKey(kind),[])||[]).slice()}
/* what was kept on this phone before the tables existed moves into the database once, finished marks included;
   the phone copy is emptied before the first await so two lists opening together cannot copy it twice */
async function kuLift(kind,rows){const L=store.get(kuKey(kind),[])||[];store.set(kuKey(kind),[]);
 const done=new Set(store.get(kuKey('done'),[])||[]),left=[],out=[];
 for(const x of L){const r=Object.assign({},x),old=r.id;delete r.id;delete r.owner;delete r.created_at;
  try{const n=await q(sb.from(kind).insert(r).select().single());out.push(n);
   if(kind==='deadlines'&&done.has(old)){done.delete(old);try{await q(sb.from('deadline_done').insert({deadline_id:n.id}))}catch(e){}}}
  catch(e){if(!/check|violates|invalid/i.test(String(e&&e.message||'')))left.push(x)}}
 if(left.length)store.set(kuKey(kind),left.concat(store.get(kuKey(kind),[])||[]));
 if(kind==='deadlines')store.set(kuKey('done'),[...done]);
 return rows.concat(out)}
async function kuPut(kind,row){
 if(KUR.db[kind]){const r=Object.assign({},row),id=r.id;delete r.id;delete r.owner;delete r.created_at;
  return id?q(sb.from(kind).update(r).eq('id',id).select().single()):q(sb.from(kind).insert(r).select().single())}
 const L=store.get(kuKey(kind),[])||[];if(row.id){const i=L.findIndex(x=>x.id===row.id);if(i>=0)L[i]=row;else L.push(row)}else{row.id=Date.now()+Math.floor(Math.random()*999);L.push(row)}store.set(kuKey(kind),L);return row}
async function kuDel(kind,id){if(KUR.db[kind]){await q(sb.from(kind).delete().eq('id',id));return}store.set(kuKey(kind),(store.get(kuKey(kind),[])||[]).filter(x=>x.id!==id))}
const kuLocalNote=kind=>KUR.db[kind]===false?`<p class="hint kuhint">${ic('lock')}ჯერჯერობით ეს ამ ტელეფონზე ინახება და მხოლოდ შენ ხედავ.</p>`:'';

/* ---------- the study tab ---------- */
R.study=()=>{view.innerHTML=`<div class="view-pad kuhub"><div class="kuhero"><div><span class="eyebrow">${KDAYL[kuDay()-1]}, ${new Date().getDate()} ${MONTHS[new Date().getMonth()]}</span><h2>სწავლა</h2></div><button class="btn sm" data-a="kuadd">${ic('plus')}დამატება</button></div>
 <section class="kucard kunow" id="kunow"><span class="spin"></span></section>
 <div class="kugrid">${[['schedule','cal','ლექციების ცხრილი','კვირის ცხრილი',250],['exams','clock','გამოცდები და დავალებები','ვადები და შეხსენებები',20],['notes','book','კონსპექტები','ჩანაწერები და ფოტოები',160],['classmates','school','კლასელები და კურსელები','სკოლა და უნივერსიტეტი',200],['rooms','video','სასწავლო ოთახები','ვიდეო-შეხვედრა',280],['tips','help','სასწავლო რჩევები','როგორ ვისწავლოთ',40]].map(([p,i,t,s,h])=>`<button class="kutile" data-a="page" data-p="${p}" style="--h:${h}"><span class="kuti">${ic(i)}</span><b>${t}</b><small>${s}</small></button>`).join('')}</div>
 <section class="kucard" id="kudue"></section><section class="kucard" id="kuedu"></section></div>`;kuHub()};
async function kuHub(){const now=new Date(),d=kuDay(now),m=now.getHours()*60+now.getMinutes();let L=[],D=[],E=[];
 try{[L,D,E]=await Promise.all([kuList('lessons'),kuList('deadlines'),kuEduOf(ME.id)])}catch(e){}
 const done=await kuDone();if(S.tab!=='study'||S.page)return;
 const today=L.filter(l=>+l.day===d&&weekOk(l,now)).sort((a,b)=>mins(a.starts)-mins(b.starts)),cur=today.find(l=>mins(l.starts)<=m&&mins(l.ends)>m),next=today.find(l=>mins(l.starts)>m);
 const el=$('#kunow');if(el)el.innerHTML=!L.length?`<div class="kuempty"><b>დაამატე ლექციების ცხრილი</b><p>ყოველ დილით აქ გამოჩნდება, რა გელოდება დღეს.</p><button class="btn sm" data-a="lessonnew">${ic('plus')}ლექციის დამატება</button></div>`
  :`<div class="kuhd"><h3>დღეს</h3><button class="hash" data-a="page" data-p="schedule">მთელი ცხრილი</button></div>${cur?`<div class="kulive">${ic('live')}<span>ახლა მიმდინარეობს</span></div>${lessonRow(cur,true)}`:''}${next?`${cur?'<p class="kusub">შემდეგი</p>':''}${lessonRow(next,!cur)}`:''}${!cur&&!next?`<p class="muted">${today.length?'დღევანდელი ლექციები დასრულდა. დაისვენე! 🎉':'დღეს ლექციები არ გაქვს.'}</p>`:''}${today.filter(l=>l!==cur&&l!==next&&mins(l.starts)>m).slice(0,3).map(l=>lessonRow(l)).join('')}`;
 const up=D.filter(x=>!done.has(x.id)&&new Date(x.due_at)>now-864e5).sort((a,b)=>new Date(a.due_at)-new Date(b.due_at)).slice(0,3),de=$('#kudue');
 if(de)de.innerHTML=`<div class="kuhd"><h3>ვადები</h3><button class="hash" data-a="page" data-p="exams">ყველა</button></div>${up.length?up.map(dlRow).join(''):`<p class="muted">ახლო ვადები არ გაქვს. <button class="hash" data-a="deadlinenew">დაამატე გამოცდა ან დავალება</button></p>`}`;
 const ee=$('#kuedu');if(ee)ee.innerHTML=E.length?`<div class="kuhd"><h3>ჩემი სკოლა და უნივერსიტეტი</h3><button class="hash" data-a="page" data-p="edu">შეცვლა</button></div><div class="pchips">${E.map(eduChip).join('')}</div><button class="btn sm ghost" data-a="page" data-p="classmates" style="margin-top:8px">${ic('users')}კლასელები და კურსელები</button>`
  :`<div class="kuempty"><b>იპოვე კლასელები და კურსელები</b><p>მიუთითე სკოლა და უნივერსიტეტი, დაგიკავშირებთ ერთად მოსწავლეებს.</p><button class="btn sm" data-a="page" data-p="edu">${ic('school')}განათლების დამატება</button></div>`}
/* the chooser comes back when back is pressed on what it opened, like the services menu */
A.kuadd=()=>{navMark('kuadd',A.kuadd);sheet(head('რა დავამატო?')+`<div class="gmenu"><button data-a="lessonnew">${ic('cal')}<span><b>ლექცია ცხრილში</b><br><small class="muted">დღე, დრო, აუდიტორია, ლექტორი</small></span></button><button data-a="deadlinenew">${ic('clock')}<span><b>გამოცდა ან დავალება</b><br><small class="muted">ვადით და შეხსენებით</small></span></button><button data-a="notenew">${ic('book')}<span><b>კონსპექტი</b><br><small class="muted">ფოტო, ტექსტი, საგანი</small></span></button><button data-a="page" data-p="edu">${ic('school')}<span><b>სკოლა ან უნივერსიტეტი</b><br><small class="muted">კლასელებისა და კურსელების საპოვნელად</small></span></button></div>`,'short')};

/* ---------- the lecture timetable ---------- */
const LKIND=[['lecture','ლექცია'],['seminar','სემინარი'],['lab','ლაბორატორია'],['lesson','გაკვეთილი'],['other','სხვა']];
const LHUES=[250,200,160,20,330,45];
const lkName=k=>(LKIND.find(x=>x[0]===k)||LKIND[0])[1];
function lessonRow(l,big){return `<button class="kurow lrow${big?' big':''}" data-a="lessonedit" data-id="${l.id}" style="--h:${+l.hue||250}"><span class="ltime"><b>${hm(l.starts)}</b><small>${hm(l.ends)}</small></span><span class="grow"><b>${esc(l.title)}</b><span class="sub">${[lkName(l.kind),l.place,l.teacher].filter(Boolean).map(esc).join(' · ')}${l.weeks&&l.weeks!=='all'?` · ${l.weeks==='odd'?'კენტ კვირებში':'ლუწ კვირებში'}`:''}</span></span></button>`}
PG.schedule={r(day){const d=+day>=1&&+day<=7?+day:(KUR.sday||kuDay());KUR.sday=d;
 view.innerHTML=pgHead('ლექციების ცხრილი',`<button class="btn sm" data-a="lessonnew">${ic('plus')}ახალი</button>`)+`<div class="seg kudays" role="group" aria-label="კვირის დღე">${KDAYS.map((x,i)=>`<button data-a="sday" data-d="${i+1}" aria-pressed="${i+1===d}"${i+1===kuDay()?' class="today"':''}>${x}</button>`).join('')}</div><div id="schb">${skel(3)}</div>`;kuSched()}};
A.sday=t=>{KUR.sday=+t.dataset.d;$$('[data-a="sday"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)));kuSched()};
async function kuSched(){const el=$('#schb');if(!el)return;let L=[];try{L=await kuList('lessons')}catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e));return}if(!el.isConnected)return;KUR.cache.lessons=L;
 const d=KUR.sday,list=L.filter(l=>+l.day===d).sort((a,b)=>mins(a.starts)-mins(b.starts));
 el.innerHTML=kuLocalNote('lessons')+(list.length?`<div class="kulist">${list.map(l=>lessonRow(l)).join('')}</div>`:empty(`${KDAYL[d-1]}ს ლექცია არ გაქვს`,L.length?'სხვა დღეს აირჩიე ან დაამატე ახალი.':'დაამატე პირველი ლექცია: საგანი, დრო, აუდიტორია.',`<button class="btn" data-a="lessonnew">${ic('plus')}ლექციის დამატება</button>`))+(L.length?`<p class="hint">სულ ${L.length} ${L.length===1?'ლექცია':'ლექცია'} კვირაში</p>`:'')}
A.lessonnew=()=>lessonSheet(null);
A.lessonedit=t=>{const id=+t.dataset.id;const l=(KUR.cache.lessons||[]).find(x=>x.id===id);if(l)lessonSheet(l);else kuList('lessons').then(L=>{KUR.cache.lessons=L;const x=L.find(y=>y.id===id);if(x)lessonSheet(x)})};
function lessonSheet(l){const ed=!!l;l=l||{kind:'lecture',day:KUR.sday||kuDay(),starts:'10:00',ends:'11:30',weeks:'all',hue:250,title:'',place:'',teacher:''};const days=new Set([+l.day]);let kind=l.kind,weeks=l.weeks||'all',hue=+l.hue||250;
 sheet(head(ed?'ლექციის რედაქტირება':'ახალი ლექცია')+`<form class="ph-body" id="lsf">
  <label class="fld">საგანი<input id="ls_t" maxlength="80" required value="${esc(l.title)}" placeholder="მაგ. მაკროეკონომიკა"></label>
  <div class="fld">ტიპი<div class="chips pick6" id="ls_k">${LKIND.map(([k,n])=>`<button type="button" data-k="${k}" aria-pressed="${k===kind}">${n}</button>`).join('')}</div></div>
  <div class="fld">${ed?'დღე':'დღეები'}<div class="chips pick6" id="ls_d">${KDAYS.map((x,i)=>`<button type="button" data-d="${i+1}" aria-pressed="${days.has(i+1)}">${x}</button>`).join('')}</div></div>
  <div class="row2"><label class="fld grow">იწყება<input type="time" id="ls_s" required value="${hm(l.starts)}"></label><label class="fld grow">მთავრდება<input type="time" id="ls_e" required value="${hm(l.ends)}"></label></div>
  <label class="fld">აუდიტორია ან ოთახი<input id="ls_p" maxlength="60" value="${esc(l.place||'')}" placeholder="მაგ. II კორპუსი, 312"></label>
  <label class="fld">ლექტორი ან მასწავლებელი<input id="ls_te" maxlength="60" value="${esc(l.teacher||'')}" placeholder="მაგ. ნ. ბერიძე"></label>
  <div class="fld">რომელ კვირებში<div class="seg flat" id="ls_w" style="margin:0">${[['all','ყოველ კვირა'],['odd','კენტში'],['even','ლუწში']].map(([k,n])=>`<button type="button" data-w="${k}" aria-pressed="${k===weeks}">${n}</button>`).join('')}</div></div>
  <div class="fld">ფერი<div class="kuhues" id="ls_h">${LHUES.map(h=>`<button type="button" data-h="${h}" style="--h:${h}" aria-label="ფერი" aria-pressed="${h===hue}"></button>`).join('')}</div></div></form>
  <div class="ph-foot">${ed?`<button class="btn ghost danger" id="ls_del">${ic('trash')}წაშლა</button>`:''}<span class="sp"></span><button class="btn" id="ls_ok">${ic('check')}შენახვა</button></div>`);
 const tog=(sel,attr,fn)=>$$(sel+' button').forEach(b=>b.onclick=()=>fn(b));
 tog('#ls_k','k',b=>{kind=b.dataset.k;$$('#ls_k button').forEach(x=>x.setAttribute('aria-pressed',String(x===b)))});
 tog('#ls_w','w',b=>{weeks=b.dataset.w;$$('#ls_w button').forEach(x=>x.setAttribute('aria-pressed',String(x===b)))});
 tog('#ls_h','h',b=>{hue=+b.dataset.h;$$('#ls_h button').forEach(x=>x.setAttribute('aria-pressed',String(x===b)))});
 tog('#ls_d','d',b=>{const d=+b.dataset.d;if(ed){days.clear();days.add(d);$$('#ls_d button').forEach(x=>x.setAttribute('aria-pressed',String(x===b)));return}if(days.has(d)&&days.size>1)days.delete(d);else days.add(d);b.setAttribute('aria-pressed',String(days.has(d)))});
 $('#lsf').onsubmit=e=>{e.preventDefault();$('#ls_ok').click()};
 if(ed)$('#ls_del').onclick=()=>confirmSheet('ლექციის წაშლა',`„${esc(l.title)}“ ცხრილიდან წაიშლება.`,'წაშლა',async()=>{try{await kuDel('lessons',l.id);toast('წაიშალა');kuAfter()}catch(e){toast(errMsg(e))}},true);
 $('#ls_ok').onclick=async()=>{const title=$('#ls_t').value.trim(),s=$('#ls_s').value,en=$('#ls_e').value;if(!title){toast('ჩაწერე საგანი');$('#ls_t').focus();return}if(!s||!en||mins(en)<=mins(s)){toast('დასრულების დრო დაწყებაზე გვიან უნდა იყოს');return}
  const base={title,kind,starts:s,ends:en,place:$('#ls_p').value.trim(),teacher:$('#ls_te').value.trim(),weeks,hue};const b=$('#ls_ok');b.disabled=true;
  try{if(ed)await kuPut('lessons',Object.assign({},l,base,{day:[...days][0]}));else for(const d of [...days].sort())await kuPut('lessons',Object.assign({day:d},base));closeSheet();toast(ed?'შენახულია':days.size>1?`დაემატა ${days.size} დღეს`:'დაემატა ცხრილში');kuAfter()}catch(e){b.disabled=false;toast(errMsg(e))}}}
function kuAfter(){if(S.page&&S.page.id==='schedule')kuSched();else if(S.page&&S.page.id==='exams')kuExams();else if(!S.page&&S.tab==='study')kuHub()}

/* ---------- exams and assignments ---------- */
const DKIND=[['exam','გამოცდა','🎓'],['midterm','შუალედური','📝'],['quiz','ქვიზი','❓'],['task','დავალება','✏️'],['project','პროექტი','📁']];
const dkOf=k=>DKIND.find(x=>x[0]===k)||DKIND[3];
async function kuDone(){if(KUR.db.deadlines){try{const r=await q(sb.from('deadline_done').select('deadline_id'));return new Set(r.map(x=>x.deadline_id))}catch(e){return new Set()}}return new Set(store.get(kuKey('done'),[])||[])}
function dueTxt(iso){const d=new Date(iso),now=new Date(),t0=new Date(now.getFullYear(),now.getMonth(),now.getDate()),days=Math.round((new Date(d.getFullYear(),d.getMonth(),d.getDate())-t0)/864e5),tm=`${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
 if(d<now)return['ვადა გავიდა','late'];if(days===0)return[`დღეს ${tm}`,'soon'];if(days===1)return[`ხვალ ${tm}`,'soon'];if(days<7)return[`${days} დღეში`,'week'];return[`${d.getDate()} ${MONTHS[d.getMonth()].slice(0,3)}`,'']}
function dlRow(x,done){const k=dkOf(x.kind),[w,c]=dueTxt(x.due_at);return `<div class="kurow dlrow${done?' done':''}"><button class="dlchk" data-a="dldone" data-id="${x.id}" aria-label="${done?'შესრულებულია':'შესრულებულად მონიშვნა'}" aria-pressed="${!!done}">${ic('check')}</button><button class="grow dlmain" data-a="dledit" data-id="${x.id}"><span class="dlemo" aria-hidden="true">${k[2]}</span><span class="grow"><b>${esc(x.title)}</b><span class="sub">${k[1]}${x.subject?' · '+esc(x.subject):''} · ${fdate(x.due_at)}</span></span><span class="dlwhen ${done?'':c}">${done?'შესრულდა':w}</span></button></div>`}
PG.exams={r(){view.innerHTML=pgHead('გამოცდები და დავალებები',`<button class="btn sm" data-a="deadlinenew">${ic('plus')}ახალი</button>`)+`<div class="seg" role="group" aria-label="რომელი"><button data-a="dlseg" data-k="up" aria-pressed="${KUR.dseg!=='done'}">მომავალი</button><button data-a="dlseg" data-k="done" aria-pressed="${KUR.dseg==='done'}">შესრულებული</button></div><div id="dlb">${skel(3)}</div>`;kuExams()}};
A.dlseg=t=>{KUR.dseg=t.dataset.k;$$('[data-a="dlseg"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)));kuExams()};
async function kuExams(){const el=$('#dlb');if(!el)return;let D=[];try{D=await kuList('deadlines')}catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e));return}const done=await kuDone();if(!el.isConnected)return;KUR.cache.deadlines=D;KUR.cache.done=done;
 D.sort((a,b)=>new Date(a.due_at)-new Date(b.due_at));const now=Date.now();
 if(KUR.dseg==='done'){const L=D.filter(x=>done.has(x.id)).reverse();el.innerHTML=kuLocalNote('deadlines')+(L.length?`<div class="kulist">${L.map(x=>dlRow(x,true)).join('')}</div>`:empty('ჯერ არაფერი შეგისრულებია','მონიშნე დავალება შესრულებულად და აქ გადმოვა.'));return}
 const open=D.filter(x=>!done.has(x.id)),late=open.filter(x=>+new Date(x.due_at)<now),week=open.filter(x=>+new Date(x.due_at)>=now&&+new Date(x.due_at)<now+7*864e5),later=open.filter(x=>+new Date(x.due_at)>=now+7*864e5);
 const sec=(t,L)=>L.length?`<h3 class="sec2">${t}</h3><div class="kulist">${L.map(x=>dlRow(x,false)).join('')}</div>`:'';
 el.innerHTML=kuLocalNote('deadlines')+(open.length?sec('ვადა გავიდა',late)+sec('ამ კვირაში',week)+sec('მოგვიანებით',later):empty('ვადები არ გაქვს','დაამატე გამოცდა, შუალედური ან დავალება და დღეს დათვლით გეტყვით, რამდენი დარჩა.',`<button class="btn" data-a="deadlinenew">${ic('plus')}დამატება</button>`))}
A.dldone=async t=>{const id=+t.dataset.id,on=t.getAttribute('aria-pressed')!=='true';t.setAttribute('aria-pressed',String(on));
 try{if(KUR.db.deadlines){if(on)await q(sb.from('deadline_done').insert({deadline_id:id}));else await q(sb.from('deadline_done').delete().eq('deadline_id',id).eq('user_id',ME.id))}
  else{const s=new Set(store.get(kuKey('done'),[])||[]);if(on)s.add(id);else s.delete(id);store.set(kuKey('done'),[...s])}if(on){burst(t);toast('ყოჩაღ! შესრულდა ✓')}setTimeout(kuAfter,on?500:0)}catch(e){toast(errMsg(e))}};
A.deadlinenew=()=>dlSheet(null);
A.dledit=t=>{const id=+t.dataset.id,x=(KUR.cache.deadlines||[]).find(y=>y.id===id);if(x)dlSheet(x);else kuList('deadlines').then(D=>{KUR.cache.deadlines=D;const y=D.find(z=>z.id===id);if(y)dlSheet(y)})};
async function dlSheet(x){const ed=!!x;const tm=new Date(Date.now()+3*864e5);tm.setHours(10,0,0,0);x=x||{kind:'exam',title:'',subject:'',due_at:tm.toISOString(),notes:''};let kind=x.kind;const d=new Date(x.due_at);
 let subs=[];try{subs=[...new Set((KUR.cache.lessons||await kuList('lessons')).map(l=>l.title))].slice(0,30)}catch(e){}
 sheet(head(ed?'რედაქტირება':'გამოცდა ან დავალება')+`<form class="ph-body" id="dlf">
  <div class="chips pick6" id="dl_k">${DKIND.map(([k,n,e])=>`<button type="button" data-k="${k}" aria-pressed="${k===kind}">${e} ${n}</button>`).join('')}</div>
  <label class="fld">სათაური<input id="dl_t" maxlength="120" required value="${esc(x.title)}" placeholder="მაგ. შუალედური: თავები 1–4"></label>
  <label class="fld">საგანი<input id="dl_s" maxlength="80" list="dl_sl" value="${esc(x.subject||'')}" placeholder="მაგ. მაკროეკონომიკა"><datalist id="dl_sl">${subs.map(s=>`<option value="${esc(s)}">`).join('')}</datalist></label>
  <div class="row2"><label class="fld grow">თარიღი<input type="date" id="dl_d" required value="${d.getFullYear()}-${pad2(d.getMonth()+1)}-${pad2(d.getDate())}"></label><label class="fld grow">დრო<input type="time" id="dl_h" required value="${pad2(d.getHours())}:${pad2(d.getMinutes())}"></label></div>
  <label class="fld">შენიშვნა<textarea id="dl_n" maxlength="1000" rows="3" placeholder="რა უნდა გავიმეორო, რა წავიღო…">${esc(x.notes||'')}</textarea></label></form>
  <div class="ph-foot">${ed?`<button class="btn ghost danger" id="dl_del">${ic('trash')}წაშლა</button>`:''}<span class="sp"></span><button class="btn" id="dl_ok">${ic('check')}შენახვა</button></div>`);
 $$('#dl_k button').forEach(b=>b.onclick=()=>{kind=b.dataset.k;$$('#dl_k button').forEach(z=>z.setAttribute('aria-pressed',String(z===b)))});
 $('#dlf').onsubmit=e=>{e.preventDefault();$('#dl_ok').click()};
 if(ed)$('#dl_del').onclick=()=>confirmSheet('წაშლა',`„${esc(x.title)}“ წაიშლება.`,'წაშლა',async()=>{try{await kuDel('deadlines',x.id);toast('წაიშალა');kuAfter()}catch(e){toast(errMsg(e))}},true);
 $('#dl_ok').onclick=async()=>{const title=$('#dl_t').value.trim(),dd=$('#dl_d').value,hh=$('#dl_h').value||'10:00';if(!title){toast('ჩაწერე სათაური');$('#dl_t').focus();return}if(!dd){toast('აირჩიე თარიღი');return}
  const due=new Date(dd+'T'+hh);if(isNaN(+due)){toast('თარიღი ვერ წავიკითხე');return}const b=$('#dl_ok');b.disabled=true;
  try{await kuPut('deadlines',Object.assign({},x,{kind,title,subject:$('#dl_s').value.trim(),due_at:due.toISOString(),notes:$('#dl_n').value.trim()}));closeSheet();toast(ed?'შენახულია':'დაემატა');kuAfter()}catch(e){b.disabled=false;toast(errMsg(e))}}}

/* ---------- notes and study tips: posts with a tag, gathered in one place ---------- */
const SUBJ=['მათემატიკა','ფიზიკა','ქიმია','ბიოლოგია','ისტორია','ქართული','ინგლისური','ეკონომიკა','სამართალი','პროგრამირება','მედიცინა','ფსიქოლოგია'];
const TIPC=['სწავლის მეთოდები','გამოცდები','ეროვნულები','მოტივაცია','კარიერა','დროის მართვა'];
const tagOf=s=>String(s||'').trim().replace(/\s+/g,'_').replace(/[^\p{L}\p{N}_]/gu,'');
function kuLib(o){KUR.lib=o;const f=KUR.libf=KUR.libf&&KUR.libf.tag===o.tag?KUR.libf:{tag:o.tag,sub:'',q:''};
 view.innerHTML=pgHead(o.title,`<button class="btn sm" data-a="libnew">${ic('plus')}${o.add}</button>`)+`<p class="hint" style="padding:12px 16px 0">${o.hint}</p>
 <form class="search kusearch" id="libf" role="search">${ic('search')}<input class="field" id="libq" type="search" placeholder="ძიება" value="${esc(f.q)}" aria-label="ძიება"></form>
 <div class="chipsbar" id="libc" role="group" aria-label="${o.cname}"><button data-a="libsub" data-s="" aria-pressed="${!f.sub}">ყველა</button>${o.cats.map(s=>`<button data-a="libsub" data-s="${esc(s)}" aria-pressed="${f.sub===s}">${esc(s)}</button>`).join('')}</div><div id="libb">${skel(3)}</div>`;
 $('#libf').onsubmit=e=>{e.preventDefault();f.q=$('#libq').value.trim();kuLibLoad()};kuLibLoad()}
async function kuLibLoad(){const o=KUR.lib,f=KUR.libf,el=$('#libb');if(!o||!el)return;
 try{const tags=[o.tag].concat(f.sub?[tagOf(f.sub)]:[]);const rows=await fetchPosts(b=>{let x=b.contains('tags',tags).eq('hidden',false);if(f.q)x=x.ilike('body','%'+f.q.replace(/[%_]/g,'')+'%');return x.order('created_at',{ascending:false}).limit(60)});if(!el.isConnected)return;
  el.innerHTML=rows.length?`<div class="kulist">${rows.map(libCard).join('')}</div>`:empty(f.sub||f.q?'ვერაფერი მოიძებნა':o.empty,o.emptySub,`<button class="btn" data-a="libnew">${ic('plus')}${o.add}</button>`);staggerIn($$('.libcard',el).slice(0,8))}
 catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
function libCard(p){const u=p.ap||prof(p.author),lines=String(p.body||'').split('\n').map(s=>s.replace(/#[\p{L}\p{N}_]+/gu,'').trim()).filter(Boolean),title=lines[0]||'უსათაურო',more=lines.slice(1).join(' '),m=pmedia(p),img=m.find(x=>x.type==='image');
 const chips=(p.tags||[]).filter(t=>t!==KUR.lib.tag).slice(0,3);
 return `<button class="libcard" data-a="page" data-p="post" data-arg="${p.id}">${img?`<span class="libimg"><img src="${esc(mSm(img))}" alt="" loading="lazy">${m.length>1?`<i>${m.length}</i>`:''}</span>`:`<span class="libimg noimg">${ic(KUR.lib.icon)}</span>`}<span class="grow"><b>${esc(title.slice(0,90))}</b>${more?`<span class="sub">${esc(more.slice(0,120))}</span>`:''}<span class="libmeta">${av(u,18)}${esc(u.name||'')} · ${ago(p.created_at)}${chips.map(t=>` <span class="ptag">#${esc(t)}</span>`).join('')}</span></span></button>`}
A.libsub=t=>{const f=KUR.libf;if(!f)return;f.sub=t.dataset.s;$$('[data-a="libsub"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)));kuLibLoad()};
A.libnew=()=>{const o=KUR.lib,f=KUR.libf;if(!o)return;compose({text:`${o.start}\n\n#${o.tag}${f&&f.sub?' #'+tagOf(f.sub):''}`})};
A.notenew=()=>{KUR.lib=NOTES;KUR.libf={tag:NOTES.tag,sub:'',q:''};A.libnew()};
const NOTES={tag:'კონსპექტი',title:'კონსპექტები',add:'კონსპექტი',icon:'book',cname:'საგანი',cats:SUBJ,start:'',hint:'ლექციების ჩანაწერები, დაფის ფოტოები და მოკლე კონსპექტები. გააზიარე შენი და ნახე კურსელების.',empty:'კონსპექტები ჯერ არ არის',emptySub:'გადაუღე ფოტო დაფას ან ჩაწერე მთავარი და გაუზიარე სხვებს.'};
const TIPS={tag:'რჩევა',title:'სასწავლო რჩევები',add:'რჩევა',icon:'help',cname:'თემა',cats:TIPC,start:'',hint:'როგორ ვისწავლოთ უკეთ: გამოცდებისთვის მზადება, დროის მართვა, მოტივაცია. დაწერე რა გიშველის შენ.',empty:'რჩევები ჯერ არ არის',emptySub:'დაწერე პირველი: რა გეხმარება სწავლაში?'};
PG.notes={r(){kuLib(NOTES)}};
PG.tips={r(){kuLib(TIPS)}};

/* ---------- schools and universities ---------- */
const UNIS=[['tsu','ივანე ჯავახიშვილის სახელობის თბილისის სახელმწიფო უნივერსიტეტი','თსუ'],['gtu','საქართველოს ტექნიკური უნივერსიტეტი','სტუ'],['iliauni','ილიას სახელმწიფო უნივერსიტეტი','ილიაუნი'],['freeuni','თავისუფალი უნივერსიტეტი','თავისუფალი'],['agruni','საქართველოს აგრარული უნივერსიტეტი','აგრარული'],['tsmu','თბილისის სახელმწიფო სამედიცინო უნივერსიტეტი','სამედიცინო'],
 ['cu','კავკასიის უნივერსიტეტი','კავკასიის'],['ibsu','საერთაშორისო შავი ზღვის უნივერსიტეტი','IBSU'],['gipa','საზოგადოებრივ საქმეთა ინსტიტუტი','GIPA'],['btu','ბიზნესისა და ტექნოლოგიების უნივერსიტეტი','BTU'],['ug','საქართველოს უნივერსიტეტი','UG'],['gau','საქართველოს ამერიკული უნივერსიტეტი','GAU'],['eu','ევროპის უნივერსიტეტი','ევროპის'],
 ['sdasu','საქართველოს დავით აღმაშენებლის სახელობის უნივერსიტეტი','SDASU'],['alte','ალტე უნივერსიტეტი','ალტე'],['newvision','ნიუ ვიჟენ უნივერსიტეტი','ნიუ ვიჟენი'],['eeu','აღმოსავლეთ ევროპის უნივერსიტეტი','EEU'],['tsaa','თბილისის სახელმწიფო სამხატვრო აკადემია','სამხატვრო'],['tsc','თბილისის სახელმწიფო კონსერვატორია','კონსერვატორია'],
 ['atsu','აკაკი წერეთლის სახელმწიფო უნივერსიტეტი','აწსუ'],['kiu','ქუთაისის საერთაშორისო უნივერსიტეტი','KIU'],['bsu','ბათუმის შოთა რუსთაველის სახელმწიფო უნივერსიტეტი','ბსუ'],['gori','გორის სახელმწიფო უნივერსიტეტი','გორის'],['telavi','თელავის სახელმწიფო უნივერსიტეტი','თელავის'],['sjsu','სამცხე-ჯავახეთის სახელმწიფო უნივერსიტეტი','სამცხე-ჯავახეთის'],['zssu','ზუგდიდის სახელმწიფო სასწავლო უნივერსიტეტი','ზუგდიდის']];
const FACS=['ეკონომიკა და ბიზნესი','სამართალი','მედიცინა','ინფორმატიკა','მათემატიკა','ფიზიკა','ქიმია','ბიოლოგია','ფსიქოლოგია','ჟურნალისტიკა','საერთაშორისო ურთიერთობები','ჰუმანიტარული მეცნიერებები','ინჟინერია','არქიტექტურა','განათლება','ხელოვნება'];
const uniShort=e=>{const u=UNIS.find(x=>x[0]===e.key);return u?u[2]:e.n};
function eduKey(e){if(e.k==='uni'){const u=UNIS.find(x=>x[1]===e.n||x[2]===e.n||x[0]===e.uk);return u?u[0]:'x-'+kuSlug(e.n)}const num=String(e.n||'').match(/\d+/);return kuSlug(e.c||'')+'-'+(num?num[0]:kuSlug(e.n))}
const eduChip=e=>`<span class="pchip">${ic(e.k==='uni'?'school':'book')}${esc(e.k==='uni'?uniShort(e):e.n)}${e.k==='uni'&&e.f?' · '+esc(e.f):''}${e.y1||e.y0?' · '+(e.k==='uni'?(e.y0||'')+(e.y1?'–'+e.y1:''):e.y1):''}${e.cls?' „'+esc(e.cls)+'“':''}</span>`;
async function kuEduOf(uid){if(!uid)return[];const local=()=>uid===ME.id?(store.get(kuKey('edu'),[])||[]):[];
 if(KUR.db.edu===false)return local();
 try{const r=await q(sb.from('profiles').select('id,edu').eq('id',uid).maybeSingle());KUR.db.edu=true;const E=Array.isArray(r&&r.edu)?r.edu:[];
  if(uid===ME.id&&!E.length){const L=local();if(L.length){store.set(kuKey('edu'),[]);kuEduSave(L).catch(()=>store.set(kuKey('edu'),L));return L}}
  return E}catch(e){if(!kuMissing(e))return local();KUR.db.edu=false;return local()}}
async function kuEduSave(list){list=list.slice(0,8);if(KUR.db.edu!==false){try{await q(sb.from('profiles').update({edu:list}).eq('id',ME.id));KUR.db.edu=true;return true}catch(e){if(!kuMissing(e))throw e;KUR.db.edu=false}}store.set(kuKey('edu'),list);return false}
PG.edu={r(){view.innerHTML=pgHead('ჩემი განათლება',`<button class="btn sm" data-a="eduadd">${ic('plus')}დამატება</button>`)+`<p class="hint" style="padding:12px 16px 0">სკოლა და უნივერსიტეტი, სადაც სწავლობ ან სწავლობდი. ამით გიპოვით კლასელებსა და კურსელებს და შეგიყვანთ კლასისა და კურსის ჯგუფებში.</p><div id="edub">${skel(2)}</div>`;kuEduPage()}};
async function kuEduPage(){const el=$('#edub');if(!el)return;const E=await kuEduOf(ME.id);if(!el.isConnected)return;KUR.cache.edu=E;
 el.innerHTML=(KUR.db.edu===false?`<p class="hint kuhint">${ic('lock')}ჯერჯერობით ეს ამ ტელეფონზე ინახება. კლასელების ძებნა ბაზის განახლების შემდეგ ჩაირთვება.</p>`:'')+(E.length?`<div class="kulist">${E.map((e,i)=>`<div class="kurow edurow"><span class="eduic">${ic(e.k==='uni'?'school':'book')}</span><span class="grow"><b>${esc(e.k==='uni'?e.n:e.n)}</b><span class="sub">${[e.c,e.f,e.k==='uni'?((e.y0||'')+(e.y1?'–'+e.y1:'')):(e.y1?e.y1+' წლის გამოშვება':''),e.cls?'კლასი „'+e.cls+'“':''].filter(Boolean).map(esc).join(' · ')}</span></span><button class="ibtn sm" data-a="eduedit" data-i="${i}" aria-label="რედაქტირება">${ic('edit')}</button></div>`).join('')}</div>
  <div class="row2" style="padding:0 16px;justify-content:flex-start;flex-wrap:wrap;gap:8px"><button class="btn" data-a="page" data-p="classmates">${ic('users')}კლასელები და კურსელები</button>${KUR.db.edu?`<button class="btn ghost" data-a="edugroups">${ic('users')}კლასისა და კურსის ჯგუფები</button>`:''}</div>`
  :empty('ჯერ არაფერი დაგიმატებია','დაამატე სკოლა ან უნივერსიტეტი.',`<button class="btn" data-a="eduadd">${ic('plus')}დამატება</button>`))}
A.eduadd=()=>eduSheet(-1);
A.eduedit=t=>eduSheet(+t.dataset.i);
function eduSheet(i){const E=(KUR.cache.edu||[]).slice(),e=i>=0?Object.assign({},E[i]):{k:'school',n:'',c:ME.city||'',y0:'',y1:'',cls:'',f:''};const yr=new Date().getFullYear();
 const draw=()=>{const isU=e.k==='uni';
  $('#eduf').innerHTML=`<div class="seg flat" style="margin:0"><button type="button" data-k="school" aria-pressed="${!isU}">${ic('book')}სკოლა</button><button type="button" data-k="uni" aria-pressed="${isU}">${ic('school')}უნივერსიტეტი</button></div>
  ${isU?`<label class="fld">უნივერსიტეტი<input id="ed_n" list="ed_ul" maxlength="80" required value="${esc(e.n)}" placeholder="დაიწყე წერა: თსუ, ილიაუნი…"><datalist id="ed_ul">${UNIS.map(u=>`<option value="${esc(u[1])}">${esc(u[2])}</option>`).join('')}</datalist></label>
   <label class="fld">ფაკულტეტი ან პროგრამა<input id="ed_f" list="ed_fl" maxlength="50" value="${esc(e.f||'')}" placeholder="მაგ. ეკონომიკა და ბიზნესი"><datalist id="ed_fl">${FACS.map(f=>`<option value="${esc(f)}">`).join('')}</datalist></label>
   <div class="row2"><label class="fld grow">ჩარიცხვის წელი<input id="ed_y0" type="number" inputmode="numeric" min="1950" max="${yr+1}" value="${esc(e.y0||'')}" placeholder="${yr-1}"></label><label class="fld grow">დამთავრება<input id="ed_y1" type="number" inputmode="numeric" min="1950" max="${yr+8}" value="${esc(e.y1||'')}" placeholder="${yr+3}"></label></div>`
  :`<label class="fld">სკოლა<input id="ed_n" maxlength="80" required value="${esc(e.n)}" placeholder="მაგ. 51-ე საჯარო სკოლა"></label><label class="fld">ქალაქი ან სოფელი<input id="ed_c" maxlength="40" value="${esc(e.c||'')}" placeholder="მაგ. თბილისი"></label>
   <div class="row2"><label class="fld grow">დამთავრების წელი<input id="ed_y1" type="number" inputmode="numeric" min="1950" max="${yr+12}" value="${esc(e.y1||'')}" placeholder="${yr}"></label><label class="fld grow">კლასი (ასო)<input id="ed_cls" maxlength="4" value="${esc(e.cls||'')}" placeholder="ა, ბ, გ…"></label></div>`}`;
  $$('#eduf [data-k]').forEach(b=>b.onclick=()=>{read();e.k=b.dataset.k;e.n='';draw()})};
 const read=()=>{const v=id=>{const x=$('#'+id);return x?x.value.trim():undefined};e.n=v('ed_n')||'';if(e.k==='uni'){e.f=v('ed_f')||'';e.y0=v('ed_y0')||'';e.y1=v('ed_y1')||'';e.c='';e.cls=''}else{e.c=v('ed_c')||'';e.y1=v('ed_y1')||'';e.cls=v('ed_cls')||'';e.f='';e.y0=''}};
 sheet(head(i>=0?'რედაქტირება':'სკოლა ან უნივერსიტეტი')+`<form class="ph-body" id="eduf"></form><div class="ph-foot">${i>=0?`<button class="btn ghost danger" id="ed_del">${ic('trash')}წაშლა</button>`:''}<span class="sp"></span><button class="btn" id="ed_ok">${ic('check')}შენახვა</button></div>`);
 draw();$('#eduf').onsubmit=ev=>{ev.preventDefault();$('#ed_ok').click()};
 const save=async L=>{try{const db=await kuEduSave(L);KUR.cache.edu=L;closeSheet();toast(db?'შენახულია':'შენახულია ამ ტელეფონზე');if(db)sb.rpc('join_edu_groups').then(()=>{},()=>{});kuEduPage()}catch(er){toast(errMsg(er))}};
 if(i>=0)$('#ed_del').onclick=()=>{E.splice(i,1);save(E)};
 $('#ed_ok').onclick=()=>{read();if(e.n.length<2){toast(e.k==='uni'?'ჩაწერე უნივერსიტეტი':'ჩაწერე სკოლა');return}const y=k=>e[k]===''||/^\d{4}$/.test(String(e[k]));if(!y('y0')||!y('y1')){toast('წელი ოთხი ციფრით ჩაწერე');return}
  const o={k:e.k,n:e.n.slice(0,80)};if(e.c)o.c=e.c.slice(0,40);if(e.f)o.f=e.f.slice(0,50);if(e.y0)o.y0=+e.y0;if(e.y1)o.y1=+e.y1;if(e.cls)o.cls=e.cls.slice(0,4);o.key=eduKey(o);
  if(i>=0)E[i]=o;else E.push(o);save(E)}}
A.edugroups=async()=>{try{const ids=await q(sb.rpc('join_edu_groups'));toast(ids&&ids.length?`ჯგუფები: ${ids.length}`:'ჯგუფები ვერ შეიქმნა');openPage('groups')}catch(e){toast(kuMissing(e)?'ჯგუფები ბაზის განახლების შემდეგ ჩაირთვება':errMsg(e))}};
PG.classmates={r(){view.innerHTML=pgHead('კლასელები და კურსელები')+`<div id="cmb">${skel(4)}</div>`;kuMates()}};
async function kuMates(){const el=$('#cmb');if(!el)return;const E=await kuEduOf(ME.id);if(!el.isConnected)return;
 if(!E.length){el.innerHTML=empty('ჯერ სკოლა არ მიგითითებია','დაამატე სკოლა ან უნივერსიტეტი და გიპოვით, ვინ სწავლობდა შენთან ერთად.',`<button class="btn" data-a="page" data-p="edu">${ic('plus')}განათლების დამატება</button>`);return}
 if(KUR.db.edu===false){el.innerHTML=empty('ძებნა მალე ჩაირთვება','კლასელების ძებნას ბაზის განახლება სჭირდება. შენი სკოლა და უნივერსიტეტი უკვე შენახულია და მერე ავტომატურად გამოჩნდება.',`<button class="btn ghost" data-a="page" data-p="edu">${ic('edit')}ჩემი განათლება</button>`);return}
 try{const out=[];for(const e of E){const rows=await q(sb.from('profiles').select(PCOLS+',edu').contains('edu',[{k:e.k,key:e.key}]).neq('id',ME.id).eq('onboarded',true).limit(200));
   const same=[],near=[],rest=[];for(const p of rows){const x=(p.edu||[]).find(y=>y.k===e.k&&y.key===e.key)||{};
    if(e.k==='school'){if(e.y1&&+x.y1===+e.y1&&(!e.cls||!x.cls||String(x.cls).toLowerCase()===String(e.cls).toLowerCase()))same.push([p,x]);else rest.push([p,x])}
    else{const fs=e.f&&x.f&&kuSlug(x.f)===kuSlug(e.f);if(fs&&e.y0&&+x.y0===+e.y0)same.push([p,x]);else if(fs)near.push([p,x]);else rest.push([p,x])}}
   rest.sort((a,b)=>Math.abs((+a[1].y1||0)-(+e.y1||0))-Math.abs((+b[1].y1||0)-(+e.y1||0)));out.push({e,same,near,rest})}
  const person=([p,x])=>`<div class="row"><button class="grow row-in" data-a="user" data-u="${p.id}">${av(p,44)}<span class="grow"><b>${esc(p.name)}${vb(p)}</b><span class="sub">${[x.f,x.y0&&x.k==='uni'?x.y0+' წლის ჩარიცხვა':'',x.y1&&x.k==='school'?x.y1+' წლის გამოშვება':'',p.city].filter(Boolean).map(esc).join(' · ')}</span></span></button>${friendBtn(p.id)}</div>`;
  const block=(t,L)=>L.length?`<h3 class="sec2">${t} · ${L.length}</h3><div class="list">${L.slice(0,60).map(person).join('')}</div>`:'';
  el.innerHTML=out.map(({e,same,near,rest})=>`<section class="kumates"><div class="kuhd"><h3>${ic(e.k==='uni'?'school':'book')}${esc(e.k==='uni'?uniShort(e):e.n)}</h3><button class="hash" data-a="edugroups">ჯგუფში შესვლა</button></div>
   ${block(e.k==='uni'?`კურსელები${e.f?' · '+esc(e.f):''}${e.y0?' · '+e.y0:''}`:`კლასელები${e.y1?' · '+e.y1:''}`,same)}${block('იგივე ფაკულტეტი, სხვა წელი',near)}${block(e.k==='uni'?'იგივე უნივერსიტეტი':'იგივე სკოლა, სხვა წელი',rest)}
   ${same.length+near.length+rest.length?'':`<p class="muted" style="padding:4px 16px 12px">აქ ჯერ არავინ მიუთითებია. მოიწვიე შენი კლასელები და კურსელები!</p><button class="btn sm ghost" data-a="invite" style="margin:0 16px 12px">${ic('send')}მოწვევა</button>`}</section>`).join('')}
 catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
/* the education chips on a profile, filled in after the profile is drawn */
async function kuProfileEdu(uid){const el=document.getElementById('pedu');if(!el)return;const E=await kuEduOf(uid);if(!el.isConnected||el.dataset.u!==String(uid))return;
 el.innerHTML=E.length?`<div class="pchips">${E.map(eduChip).join('')}</div>`:(uid===ME.id?`<button class="pchip" data-a="page" data-p="edu">${ic('plus')}სკოლა ან უნივერსიტეტი</button>`:'');el.hidden=!el.innerHTML}

/* menu entries that are tabs (dating moved from the tab bar into the menu), and the create menu's study entries */
A.tabgo=t=>go(t.dataset.p);
A.cnote=()=>A.notenew();
A.clesson=()=>A.lessonnew();
A.cexam=()=>A.deadlinenew();
