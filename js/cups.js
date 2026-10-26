/* ---------- cups among friends, and duels between two groups (villages, surnames, any group) ----------
   a cup: someone names it and picks the game, friends join, the host starts it and the bracket is drawn (a missing
   place is a bye). each match is a live online game between the two players; when it ends both phones report the
   result as in any game with a person, and the cup moves on by itself.
   a duel: an admin of one group calls out another open group; members of both join their side, the host starts it,
   the sides are paired in joining order and each pair plays one game; the side with more wins takes it.
   everything lives in game_cups, game_cup_players and game_cup_matches; until those exist the pages say so */
const CUPG=['nardi','shashi','chess'];
const CUP={gids:{},ch:null,id:null,v:null};
const cupMissing=e=>/PGRST20[25]|42P01|42883|Could not find|does not exist|schema cache/i.test(String(e&&((e.code||'')+' '+(e.message||''))||e));
const CUPERR={friends_only:'თასში მასპინძლის მეგობრები მონაწილეობენ',full:'ადგილები შევსებულია',not_member:'ამ მხარეს მხოლოდ ჯგუფის წევრები თამაშობენ',not_admin:'დუელს ჯგუფის ადმინისტრატორი აცხადებს',private_group:'დახურულ ჯგუფს დუელში ვერ გამოიწვევ',too_few:'მოთამაშეები ჯერ საკმარისი არ არის',too_many:'დღეში ხუთზე მეტ თასს ვერ გამართავ',bad_size:'ასეთი ზომა არ შეიძლება',not_allowed:'ამის უფლება არ გაქვს'};
const cupErr=e=>{if(cupMissing(e))return 'თასები და დუელები ბაზის განახლების შემდეგ ჩაირთვება';const m=String(e&&e.message||e||'');for(const k in CUPERR)if(m.includes(k))return CUPERR[k];return errMsg(e)};
const cupGame=k=>GAMES.find(x=>x.id===k)||{n:k,ac:'#C9A227'};
const cupSoon=()=>`<section class="tourcard"><p class="note">${ic('clock')} თასები და ჯგუფების დუელები ბაზის განახლების შემდეგ ჩაირთვება. მანამდე ტურნირი ბოტებთან ლობიშია.</p></section>`;
const cupRound=(k,R)=>{const f=R-k;return f===0?'ფინალი':f===1?'ნახევარფინალი':f===2?'მეოთხედფინალი':'1/'+2**f+' ფინალი'};
const cupStatus=c=>c.status==='open'?'იკრიბება':c.status==='play'?'მიმდინარეობს':c.status==='done'?'დასრულდა':'დაიხურა';

/* ---------- the list: mine, friends' open cups, my groups' duels ---------- */
PG.cups={r(){view.innerHTML=pgHead('თასები და დუელები')+`<div class="view-pad"><section class="tourcard"><p class="note">თასი მეგობრებთან: გამოთიშვის სისტემა, ყოველი მატჩი ცოცხალი პარტიაა. დუელი: შენი ჯგუფი მეორე ჯგუფის წინააღმდეგ, სოფელი სოფლის, გვარი გვარის.</p><div class="jkacts"><button class="btn gold" data-a="cupnew">${ic('crown')}ახალი თასი</button><button class="btn ghost" data-a="cupduel">${ic('flag')}ჯგუფების დუელი</button></div></section><div id="cupl">${skel(3)}</div></div>`;cupList()}};
async function cupList(){const el=()=>$('#cupl');let mine=[],open=[],duels=[],mm=[];
 try{const ids=(await q(sb.from('game_cup_players').select('cup_id').eq('user_id',ME.id).order('joined_at',{ascending:false}).limit(40))).map(x=>x.cup_id);
  const fr=[...FRIENDS].slice(0,150);const myg=(await q(sb.from('group_members').select('group_id').eq('user_id',ME.id).limit(200))).map(x=>x.group_id);
  [mine,open,duels]=await Promise.all([ids.length?q(sb.from('game_cups').select('*').in('id',ids).neq('status','closed').order('created_at',{ascending:false})):[],
   fr.length?q(sb.from('game_cups').select('*').eq('kind','cup').eq('status','open').in('host',fr).order('created_at',{ascending:false}).limit(20)):[],
   myg.length?q(sb.from('game_cups').select('*').eq('kind','duel').in('status',['open','play']).or(`group_a.in.(${myg.join(',')}),group_b.in.(${myg.join(',')})`).order('created_at',{ascending:false}).limit(20)):[]]);
  const live=mine.filter(c=>c.status==='play').map(c=>c.id);if(live.length)mm=await q(sb.from('game_cup_matches').select('cup_id,p1,p2,status').in('cup_id',live).eq('status','wait').or(`p1.eq.${ME.id},p2.eq.${ME.id}`))}
 catch(e){if(!el())return;el().innerHTML=cupMissing(e)?cupSoon():`<p class="note">სია ვერ ჩაიტვირთა. ${esc(errMsg(e))}</p>`;return}
 const seen=new Set(mine.map(c=>c.id));open=open.filter(c=>!seen.has(c.id));open.forEach(c=>seen.add(c.id));duels=duels.filter(c=>!seen.has(c.id));
 const gids=[...new Set([...mine,...duels].flatMap(c=>[c.group_a,c.group_b]).filter(Boolean))];let gn={};
 if(gids.length)try{for(const g of await q(sb.from('groups').select('id,name').in('id',gids)))gn[g.id]=g.name}catch(e){}
 await loadProfiles([...mine,...open,...duels].map(c=>c.host));if(!el())return;
 const turn=new Set(mm.filter(m=>m.p1&&m.p2).map(m=>m.cup_id));
 const row=c=>{const g=cupGame(c.game),t=turn.has(c.id);return `<button class="row crow${t?' mine':''}" data-a="cupopen" data-id="${c.id}"><span class="cupic" style="--ac:${g.ac}">${ic(c.kind==='duel'?'flag':'crown')}</span><span class="grow"><b>${esc(c.name)}</b><span class="sub">${g.n} · ${c.kind==='duel'?esc((gn[c.group_a]||'?')+' — '+(gn[c.group_b]||'?')):esc(pname(c.host))} · ${t?'შენი მატჩი გელოდება':cupStatus(c)}</span></span>${t?'<span class="badge">მატჩი</span>':''}</button>`};
 const sec=(h,L)=>L.length?`<h3 class="sec">${h}</h3><div class="ph-body">${L.map(row).join('')}</div>`:'';
 const body=sec('ჩემი',mine)+sec('მეგობრები გიწვევენ',open)+sec('ჩემი ჯგუფების დუელები',duels);
 el().innerHTML=body||empty('თასი ჯერ არ არის','გამართე პირველი: აირჩიე თამაში და მოიწვიე მეგობრები.','')}
A.cupopen=t=>openPage('cup',+t.dataset.id);

/* ---------- a new cup ---------- */
A.cupnew=()=>{const st={g:'nardi',n:8};const seg=(k,L)=>`<div class="seg flat" role="group" data-k="${k}">${L.map(([v,l])=>`<button type="button" data-v="${v}" aria-pressed="${String(st[k])===String(v)}">${l}</button>`).join('')}</div>`;
 sheet(head('ახალი თასი')+`<div class="ph-body form"><label class="fld">სახელი<input id="cu_n" maxlength="60" value="${esc(String(ME.name||'').split(' ')[0]+'ის თასი')}"></label>
  <p class="cuplbl">თამაში</p>${seg('g',CUPG.map(g=>[g,cupGame(g).n]))}<p class="cuplbl">მოთამაშეები</p>${seg('n',[[4,'4'],[8,'8'],[16,'16']])}
  <p class="note">მეგობრებს შექმნისთანავე მოიწვევ. თასს შენ დაიწყებ, როცა საკმარისი ხალხი შეიკრიბება; ცარიელი ადგილი თავისუფალი გასვლაა.</p></div><div class="ph-foot"><span class="sp"></span><button class="btn gold" id="cu_ok">${ic('crown')}შექმნა</button></div>`,'short');
 cupSeg(st);$('#cu_ok').onclick=async()=>{const n=$('#cu_n').value.trim();if(n.length<2){toast('ჩაწერე სახელი');return}const b=$('#cu_ok');b.disabled=true;
  try{const id=await rpc('cup_create',{p_kind:'cup',p_game:st.g,p_name:n,p_size:+st.n});closeSheet();openPage('cup',id);setTimeout(()=>cupInvite(id),350)}catch(e){toast(cupErr(e));b.disabled=false}}};
function cupSeg(st){$$('#sheet .seg[data-k]').forEach(s=>s.onclick=e=>{const b=e.target.closest('button');if(!b)return;st[s.dataset.k]=b.dataset.v;$$('button',s).forEach(x=>x.setAttribute('aria-pressed',String(x===b)))})}
/* friends hear about it in a chat message with a button that opens the cup */
async function cupNote(u,id,body){try{const c=await rpc('start_dm',{other:u});await q(sb.from('messages').insert({conv_id:c,sender:ME.id,body,media:{game:{gt:'cup',tbl:id}}}))}catch(e){}}
function cupInvite(id){const v=CUP.v;const ex=new Set(v&&v.c.id===id?v.pl.map(p=>p.user_id):[ME.id]);
 friendPicker('ვის მოვიწვიოთ თასზე?','მოწვევა',async sel=>{closeSheet();const c=CUP.v&&CUP.v.c;for(const u of sel)cupNote(u,id,`🏆 ${c?c.name:'თასი'}: გიწვევ ${c?cupGame(c.game).n+'ის ':''}თასზე!`);toast('მოწვევა გაიგზავნა')},ex)}
A.cupinv=t=>cupInvite(+t.dataset.id);

/* ---------- a duel: my group against another ---------- */
A.cupduel=async()=>{let mine=[];try{const[own,adm]=await Promise.all([q(sb.from('groups').select('id,name').eq('owner',ME.id).limit(50)),q(sb.from('group_members').select('group_id,role').eq('user_id',ME.id).in('role',['owner','admin']).limit(50))]);
  const ids=adm.map(x=>x.group_id).filter(i=>!own.some(g=>g.id===i));mine=own.concat(ids.length?await q(sb.from('groups').select('id,name').in('id',ids)):[])}catch(e){toast(errMsg(e));return}
 if(!mine.length){toast('დუელს ჯგუფის ადმინისტრატორი აცხადებს. ჯერ შექმენი ჯგუფი ან სთხოვე ადმინს');return}
 const st={a:mine[0].id,b:null,bn:'',g:'nardi',n:5};const seg=(k,L)=>`<div class="seg flat" role="group" data-k="${k}">${L.map(([v,l])=>`<button type="button" data-v="${v}" aria-pressed="${String(st[k])===String(v)}">${l}</button>`).join('')}</div>`;
 sheet(head('ჯგუფების დუელი')+`<div class="ph-body form"><label class="fld">ჩემი ჯგუფი<select id="cd_a">${mine.map(g=>`<option value="${g.id}">${esc(g.name)}</option>`).join('')}</select></label>
  <label class="fld">ვის ვიწვევთ<input id="cd_q" maxlength="60" placeholder="მოძებნე ჯგუფი: სოფელი, გვარი…" autocomplete="off"></label><div id="cd_r" class="cdres"></div>
  <p class="cuplbl">თამაში</p>${seg('g',CUPG.map(g=>[g,cupGame(g).n]))}<p class="cuplbl">თითო მხარეს</p>${seg('n',[[3,'3 მოთამაშე'],[5,'5'],[7,'7']])}
  <p class="note">წყვილები შეერთების რიგით დგება. ყოველი წყვილი ერთ პარტიას თამაშობს; ვისაც მეტი მოგება ექნება, ის იმარჯვებს.</p></div><div class="ph-foot"><span class="sp"></span><button class="btn gold" id="cd_ok">${ic('flag')}გამოწვევა</button></div>`);
 cupSeg(st);const sel=$('#cd_a');sel.onchange=()=>{st.a=+sel.value};let tm=0;
 $('#cd_q').oninput=e=>{clearTimeout(tm);const s=e.target.value.trim();tm=setTimeout(async()=>{const r=$('#cd_r');if(!r)return;if(s.length<2){r.innerHTML='';return}
  try{const L=(await q(sb.from('groups').select('id,name,hue,avatar_url').eq('is_private',false).ilike('name','%'+s.replace(/[%_,()]/g,' ')+'%').limit(8))).filter(g=>g.id!==st.a);
   r.innerHTML=L.map(g=>`<button type="button" class="row pick${g.id===st.b?' on':''}" data-id="${g.id}" data-n="${esc(g.name)}"><span class="grow"><b>${esc(g.name)}</b></span>${g.id===st.b?ic('check'):''}</button>`).join('')||'<p class="muted">ასეთი ღია ჯგუფი ვერ ვიპოვე</p>'}catch(x){r.innerHTML=''}},260)};
 $('#cd_r').onclick=e=>{const b=e.target.closest('button[data-id]');if(!b)return;st.b=+b.dataset.id;st.bn=b.dataset.n;$$('#cd_r button').forEach(x=>{const on=x===b;x.classList.toggle('on',on);const i=x.querySelector('svg');if(i)i.remove();if(on)x.insertAdjacentHTML('beforeend',ic('check'))})};
 $('#cd_ok').onclick=async()=>{if(!st.b){toast('აირჩიე, რომელ ჯგუფს იწვევ');return}const an=(mine.find(g=>g.id===st.a)||{}).name||'';const b=$('#cd_ok');b.disabled=true;
  try{const id=await rpc('cup_create',{p_kind:'duel',p_game:st.g,p_name:(an+' — '+st.bn).slice(0,60),p_size:+st.n,p_group_a:st.a,p_group_b:st.b});closeSheet();
   /* the other group's owner gets a message with the duel in it */
   try{const g=await q(sb.from('groups').select('owner').eq('id',st.b).maybeSingle());if(g&&g.owner&&g.owner!==ME.id)cupNote(g.owner,id,`⚔️ ${an} იწვევს „${st.bn}“-ს დუელზე: ${cupGame(st.g).n}, ${st.n} მოთამაშე თითო მხარეს`)}catch(x){}
   openPage('cup',id)}catch(e){toast(cupErr(e));b.disabled=false}}};

/* ---------- one cup ---------- */
PG.cup={r(id){id=+id;view.innerHTML=pgHead('თასი',`<button class="ibtn" data-a="cupshare" data-id="${id}" aria-label="გაზიარება">${ic('share')}</button>`)+`<div class="view-pad" id="cupb">${skel(3)}</div>`;cupOpen(id)}};
function cupStop(){if(CUP.ch){try{sb.removeChannel(CUP.ch)}catch(e){}}CUP.ch=null;CUP.id=null}
async function cupLoad(id){const[c,pl,mt]=await Promise.all([q(sb.from('game_cups').select('*').eq('id',id).maybeSingle()),q(sb.from('game_cup_players').select('user_id,team,joined_at').eq('cup_id',id).order('joined_at')),q(sb.from('game_cup_matches').select('*').eq('cup_id',id).order('round').order('slot'))]);
 if(!c)return null;let gn={},mem={};if(c.kind==='duel'){try{for(const g of await q(sb.from('groups').select('id,name').in('id',[c.group_a,c.group_b])))gn[g.id]=g.name}catch(e){}
  try{for(const m of await q(sb.from('group_members').select('group_id').eq('user_id',ME.id).in('group_id',[c.group_a,c.group_b])))mem[m.group_id]=1}catch(e){}}
 await loadProfiles([c.host,...pl.map(p=>p.user_id),...mt.flatMap(m=>[m.p1,m.p2,m.winner])].filter(Boolean));return {c,pl,mt,gn,mem}}
async function cupOpen(id){cupStop();CUP.id=id;S.chanCleanup=cupStop;let v=null;
 try{v=await cupLoad(id)}catch(e){const el=$('#cupb');if(el)el.innerHTML=cupMissing(e)?cupSoon():`<p class="note">თასი ვერ ჩაიტვირთა. ${esc(errMsg(e))}</p>`;return}
 if(CUP.id!==id)return;if(!v){const el=$('#cupb');if(el)el.innerHTML=empty('თასი ვერ მოიძებნა','შეიძლება წაიშალა ან შენთვის დახურულია.','');return}
 CUP.v=v;cupDraw();
 /* games of mine that ended while I was away: their results settle the matches now */
 cupSettleMine(v);
 const ch=sb.channel('cup-'+id);const re=()=>{clearTimeout(CUP.rt);CUP.rt=setTimeout(cupRefresh,400)};
 ch.on('postgres_changes',{event:'*',schema:'public',table:'game_cup_matches',filter:'cup_id=eq.'+id},re).on('postgres_changes',{event:'*',schema:'public',table:'game_cup_players',filter:'cup_id=eq.'+id},re)
  .on('postgres_changes',{event:'UPDATE',schema:'public',table:'game_cups',filter:'id=eq.'+id},re).subscribe();CUP.ch=ch}
async function cupRefresh(){const id=CUP.id;if(!id||!S.page||S.page.id!=='cup')return;try{const v=await cupLoad(id);if(v&&CUP.id===id){CUP.v=v;cupDraw()}}catch(e){}}
function cupSettleMine(v){const L=v.mt.filter(m=>m.status==='wait'&&m.gid&&(m.p1===ME.id||m.p2===ME.id));if(!L.length)return;
 Promise.all(L.map(m=>rpc('cup_settle',{p_match:m.id}).catch(()=>null))).then(R=>{if(R.some(r=>r&&r.done||r&&r.again))cupRefresh()})}
const cupName=u=>u?esc(String(pname(u)).split(' ').slice(0,2).join(' ')):'…';
function cupDraw(){const el=$('#cupb'),v=CUP.v;if(!el||!v)return;const{c,pl,mt}=v,g=cupGame(c.game),inIt=pl.some(p=>p.user_id===ME.id),host=c.host===ME.id;
 const t=$('.pghead h2',view);if(t)t.textContent=c.kind==='duel'?'დუელი':'თასი';
 let h=`<section class="tourcard cuphead" style="--ac:${g.ac}"><span class="tag" style="align-self:flex-start">${c.kind==='duel'?'ჯგუფების დუელი':'თასი'} · ${g.n}</span><h3>${esc(c.name)}</h3>
  <p class="note">${c.kind==='duel'?`${c.size} მოთამაშე თითო მხარეს`:`${pl.length}/${c.size} მოთამაშე`} · მასპინძელი ${cupName(c.host)} · ${cupStatus(c)}</p>`;
 if(c.status==='done')h+=c.kind==='duel'?`<p class="cupwin">${ic('crown')} ${c.team_win==='draw'?'ფრე! ორივე მხარემ თანაბარი მოიგო':`გაიმარჯვა: <b>${esc(v.gn[c.team_win==='a'?c.group_a:c.group_b]||'')}</b>`}</p>`:`<p class="cupwin">${ic('crown')} ჩემპიონი: <b>${cupName(c.winner)}</b>${c.winner===ME.id?' — შენ! 🏆':''}</p>`;
 const my=c.status==='play'?mt.find(m=>m.status==='wait'&&m.p1&&m.p2&&(m.p1===ME.id||m.p2===ME.id)):null;
 if(my){const o=my.p1===ME.id?my.p2:my.p1,on=S.online.has(o),R=Math.round(Math.log2((mt.filter(m=>m.round===1).length||1)*2));
  h+=`<div class="cupnext"><span class="grow"><span>შენი მატჩი: <b>${cupName(o)}</b>${c.kind==='cup'?' · '+cupRound(my.round,R):''}</span><small>${on?'ახლა ონლაინაა':'ახლა ონლაინ არ არის. მიწერე, როდის ითამაშებთ'}</small></span><button class="btn gold" data-a="cupplay" data-m="${my.id}">${ic('play')}თამაში</button></div>`}
 const acts=[];if(c.status==='open'){if(!inIt&&c.kind==='cup')acts.push(`<button class="btn gold" data-a="cupjoin" data-id="${c.id}">შეერთება</button>`);
  if(inIt&&!host)acts.push(`<button class="btn ghost" data-a="cupleave" data-id="${c.id}">დატოვება</button>`);
  if(host){acts.push(`<button class="btn gold" data-a="cupstart" data-id="${c.id}">${ic('play')}დაწყება</button>`);if(c.kind==='cup')acts.push(`<button class="btn ghost" data-a="cupinv" data-id="${c.id}">${ic('plus')}მოწვევა</button>`)}}
 if(acts.length)h+=`<div class="jkacts">${acts.join('')}</div>`;h+='</section>';
 h+=c.kind==='duel'?cupDuelHTML(v):c.status==='open'?cupPlayersHTML(v):cupBracketHTML(v);el.innerHTML=h}
function cupPlayersHTML(v){return `<h3 class="sec">მოთამაშეები</h3><div class="ph-body">${v.pl.map(p=>`<div class="row">${av(p.user_id,40)}<span class="grow"><b>${cupName(p.user_id)}</b>${p.user_id===v.c.host?'<span class="sub">მასპინძელი</span>':''}</span>${S.online.has(p.user_id)?'<span class="cupon" aria-label="ონლაინ"></span>':''}</div>`).join('')}</div>`}
function cupBracketHTML(v){const{mt}=v,r1=mt.filter(m=>m.round===1).length;if(!r1)return '';const R=Math.round(Math.log2(r1*2));let h=`<div class="bwrap"><div class="bracket cupb" style="grid-template-columns:repeat(${R},minmax(124px,1fr))">`;
 for(let k=1;k<=R;k++){h+=`<div class="bcol"><h4>${cupRound(k,R)}</h4><div class="bcolm">`;for(let s=0;s<r1/2**(k-1);s++){const m=mt.find(x=>x.round===k&&x.slot===s),a=m&&m.p1,b=m&&m.p2,w=m&&m.winner,bye=m&&m.status==='done'&&(!a||!b);
   h+=`<div class="bm${m&&m.status==='wait'&&a&&b&&(a===ME.id||b===ME.id)?' mine':''}">${[a,b].map(x=>`<div class="${x&&w?(x===w?'w':'l'):''}${x===ME.id?' me':''}"><span>${x?cupName(x):bye&&(a||b)?'თავისუფალი':m&&m.status==='done'?'—':'…'}</span>${x&&w===x?'✓':''}</div>`).join('')}</div>`}h+='</div></div>'}
 return h+'</div></div>'}
function cupDuelHTML(v){const{c,pl,mt,gn,mem}=v,A=pl.filter(p=>p.team==='a'),B=pl.filter(p=>p.team==='b');let a=0,b=0;for(const m of mt)if(m.status==='done'){if(m.winner&&m.winner===m.p1)a++;else if(m.winner&&m.winner===m.p2)b++}
 const inIt=pl.some(p=>p.user_id===ME.id);
 const side=(k,L,gid)=>`<div class="cdside"><h4>${esc(gn[gid]||'?')}</h4><small>${L.length}/${c.size}</small>${L.map(p=>`<div class="cdp${p.user_id===ME.id?' me':''}">${av(p.user_id,28)}<span>${cupName(p.user_id)}</span></div>`).join('')}${c.status==='open'&&!inIt&&mem[gid]&&L.length<c.size?`<button class="btn sm gold" data-a="cupjoin" data-id="${c.id}" data-t="${k}">შეერთება</button>`:''}</div>`;
 let h=`<div class="cduel">${side('a',A,c.group_a)}<div class="cdvs">${c.status==='open'?'VS':`<b>${a}</b>:<b>${b}</b>`}</div>${side('b',B,c.group_b)}</div>`;
 if(mt.length)h+=`<h3 class="sec">წყვილები</h3><div class="ph-body">${mt.map(m=>`<div class="row cdpair${m.p1===ME.id||m.p2===ME.id?' mine':''}"><span class="${m.winner&&m.winner===m.p1?'w':''}">${cupName(m.p1)}</span><i>${m.status==='done'?'✓':'—'}</i><span class="${m.winner&&m.winner===m.p2?'w':''}">${cupName(m.p2)}</span></div>`).join('')}</div>`;
 if(c.status==='open'&&!inIt&&!mem[c.group_a]&&!mem[c.group_b])h+=`<p class="note">დუელში ორივე ჯგუფის წევრები თამაშობენ. შეუერთდი ერთ-ერთ ჯგუფს და შემდეგ დაბრუნდი.</p>`;return h}
const cupAct=(fn,args,ok)=>async t=>{t.disabled=true;try{await rpc(fn,args(t));if(ok)toast(ok);await cupRefresh()}catch(e){toast(cupErr(e))}finally{t.disabled=false}};
A.cupjoin=cupAct('cup_join',t=>({p_cup:+t.dataset.id,p_team:t.dataset.t||null}),'შეუერთდი');
A.cupleave=cupAct('cup_leave',t=>({p_cup:+t.dataset.id}),'თასი დატოვე');
A.cupstart=t=>{const v=CUP.v;if(!v)return;const n=v.pl.length;confirmSheet('დაწყება?',v.c.kind==='duel'?'წყვილები შეერთების რიგით დადგება. ახალი მოთამაშე ვეღარ შეუერთდება.':`${n} მოთამაშე. ცარიელი ადგილები თავისუფალ გასვლად ჩაითვლება.`,'დაწყება',async()=>{await cupAct('cup_start',()=>({p_cup:v.c.id}),'დაიწყო!')(t)})};
A.cupshare=t=>{const v=CUP.v,c=v&&v.c;if(!c)return;shareLink(location.origin+'/#cup-'+c.id,`🏆 ${c.name} · ${cupGame(c.game).n} სუფრაზე`)};

/* ---------- playing a match: a challenge with the cup's match on it ---------- */
A.cupplay=async t=>{const v=CUP.v,m=v&&v.mt.find(x=>x.id===+t.dataset.m);if(!m||m.status!=='wait')return;const o=m.p1===ME.id?m.p2:m.p1,c=v.c;
 if(!S.online.has(o)){cupNote(o,c.id,`🏆 ${c.name}: ჩვენი მატჩი გველოდება. როცა შემოხვალ, ვითამაშოთ!`);toast(String(pname(o)).split(' ')[0]+' ახლა ონლაინ არ არის. მივწერე, რომ მატჩი ელოდება');return}
 const gid='g'+Math.random().toString(36).slice(2,12);t.disabled=true;try{await rpc('cup_gid',{p_match:m.id,p_gid:gid})}catch(e){t.disabled=false;toast(cupErr(e));return}
 CUP.gids[gid]={m:m.id,c:c.id,n:c.name};NET.pending={gid,gt:c.game,to:o};lsend('chal',{to:o,gt:c.game,gid,nm:ME.name,cup:m.id});
 setTimeout(()=>{t.disabled=false;if(NET.pending&&NET.pending.gid===gid){NET.pending=null;toast('პასუხი არ მოვიდა')}},45000);toast('გამოწვევა გაიგზავნა. მიღებისთანავე მატჩი დაიწყება')};
/* a challenge for a cup match: checked against the match itself, and let through even past "only friends challenge me",
   since the player chose to be in the cup */
{const oc=onChal;onChal=function(d){if(!d||d.to!==ME.id||!(+d.cup>0)||!okGid(d.gid)||BLOCKED.has(d.from))return oc(d);
  q(sb.from('game_cup_matches').select('id,cup_id,p1,p2,status,gid').eq('id',+d.cup).maybeSingle()).then(async m=>{
   if(!m||m.status!=='wait'||m.gid!==d.gid||![m.p1,m.p2].includes(d.from)||![m.p1,m.p2].includes(ME.id))return oc(d);let cn='';try{const c=await q(sb.from('game_cups').select('name').eq('id',m.cup_id).maybeSingle());cn=c&&c.name||''}catch(e){}
   CUP.gids[d.gid]={m:m.id,c:m.cup_id,n:cn};const pv=ME.privacy;ME.privacy=Object.assign({},pv,{chal:'all'});try{oc(d)}finally{ME.privacy=pv}
   const p=$('#sheet .match .eyebrow');if(p)p.textContent='🏆 თასის მატჩი'+(cn?' · '+cn:'')}).catch(()=>oc(d))}}
/* the game is over: once both phones have said how it ended, the cup moves on */
function cupSettle(x,n=0){rpc('cup_settle',{p_match:x.m}).then(r=>{if(r&&r.done){toast(r.winner===ME.id?'🏆 თასში შემდეგ ეტაპზე გადახვედი!':'თასის მატჩი დასრულდა');if(S.page&&S.page.id==='cup')cupRefresh()}
  else if(r&&r.again)toast('ფრე: თასის მატჩი თავიდან ითამაშეთ');else if(r&&r.pending&&n<3)setTimeout(()=>cupSettle(x,n+1),n<1?8000:70000)}).catch(()=>{})}
{const fin=finish;finish=function(G,w){const c=G&&G.ctx,was=c&&c.finished;fin(G,w);if(was||!c||c.mode!=='online'||c.corr)return;const x=CUP.gids[c.gid];if(!x)return;c.cup=x;setTimeout(()=>cupSettle(x),3000)}}
{const rh=gResHTML;gResHTML=function(...a){const h=rh.apply(this,a),G=GAME[S.game],c=G&&G.ctx;if(!c||!c.cup||typeof h!=='string')return h;
  return h.replace('<div class="gendb">',`<div class="gendb"><button class="btn gold" data-a="cupback" data-id="${c.cup.c}">${ic('crown')}თასზე დაბრუნება</button>`)}}
A.cupback=t=>{const id=+t.dataset.id;A.lobby();setTimeout(()=>openPage('cup',id),60)};
/* the card in the chat that opens a cup or a duel */
{const gm=gameMsg;gameMsg=function(g,me,m){if(g&&g.gt==='cup'&&+g.tbl>0)return `<div class="gamemsg${me?' me':''}" style="--ac:#C9A227"><span class="cupic big">${ic('crown')}</span><div class="gmb"><b>თასი</b><small>${me?'შენ მოიწვიე':'გიწვევენ'}</small><button class="btn sm${me?' ghost':' gold'}" data-a="cupopen" data-id="${+g.tbl}">${ic('crown')}გახსნა</button></div></div>`;return gm.apply(this,arguments)}}
