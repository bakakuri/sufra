/* who may play what. The admin sets it in the admin panel (ადმინი → თამაშები), and it is kept in app_settings:
   games_lock {on}: all games closed to everyone but the admin (the server keeps the same lock for the casino: private.games_open);
   games {off:[game ids], goff:[group keys]}: whole groups or single games switched off for everyone but the admin.
   Until the settings have come the lock counts as on, so nothing opens by accident while the page loads.
   A switched-off game disappears from the lists, and whatever would open it says it is switched off for now */
const GGROUPS=[
 ['board','სამაგიდო თამაშები',[['nardi','ნარდი'],['shashi','შაში'],['chess','ჭადრაკი'],['joker','ჯოკერი'],['domino','დომინო'],['durak','დურაკი'],['bura','ბურა'],['loto','ლოტო'],['egg','კვერცხის ჭახუნი']]],
 ['modes','რეჟიმები და შეჯიბრებები',[['tables','მეგობრების მაგიდები (ჯოკერი, დომინო, ლოტო ონლაინ)'],['corrs','მიმოწერით თამაში'],['cups','თასები და დუელები'],['tour','ტურნირები'],['career','ეზოდან ჩემპიონატამდე'],['daily','დღის ხელი'],['puzzles','ამოცანები და სპრინტი']]],
 ['slots','სლოტები',[['slot','ქართული სლოტი'],['fleece','ოქროს საწმისი'],['batumi','ბათუმის ღამე']]],
 ['casino','კაზინო',[['roulette','რულეტკა'],['bj','ბლექჯეკი']]],
 ['fast','სწრაფი თამაშები',[['aviator','ავიატორი'],['mines','ნაღმები'],['plinko','პლინკო']]]];
const GG_OF={},GG_N={};GGROUPS.forEach(([k,,gs])=>gs.forEach(([id,n])=>{GG_OF[id]=k;GG_N[id]=n}));
/* the casino games the server switches too (app_settings casino.games); the shared aviator goes with the aviator */
const GG_CS={slot:['slot'],fleece:['fleece'],batumi:['batumi'],roulette:['roulette'],bj:['bj'],aviator:['aviator','avl'],mines:['mines'],plinko:['plinko']};
const gSet=()=>{const A=typeof APPSET!=='undefined'&&APPSET||{},g=A.games||{};return{lock:A.games_lock?A.games_lock.on!==false:true,off:new Set(g.off||[]),goff:new Set(g.goff||[])}};
const gAdm=()=>!!(typeof ME!=='undefined'&&ME&&ME.role==='admin');
const gLocked=()=>!gAdm()&&gSet().lock;
const gGroupOff=k=>{if(gAdm())return false;const s=gSet();return s.lock||s.goff.has(k)};
const gOff=id=>{if(gAdm())return false;const s=gSet();return s.lock||s.goff.has(GG_OF[id])||s.off.has(id)};
const gOffMsg=id=>toast(`${GG_N[id]||'ეს თამაში'} დროებით გამორთულია`);
const GLOCK_PAGES=['slot','fleece','batumi','roulette','bj','aviator','mines','plinko','gkind','jktable','dmtable','lotable','career','corrs','cup','cups','replay','tour'];
/* the game a page belongs to */
const GPAGE_G={slot:'slot',fleece:'fleece',batumi:'batumi',roulette:'roulette',bj:'bj',aviator:'aviator',mines:'mines',plinko:'plinko',jktable:'tables',dmtable:'tables',lotable:'tables',corrs:'corrs',cup:'cups',cups:'cups',tour:'tour',career:'career'};
const gLockHTML=()=>`<div class="view-pad glock"><div class="glock-c"><span class="glock-i">${ic('lock')}</span><h2>თამაშები დროებით შეზღუდულია</h2><p>თამაშებზე წვდომა ამჟამად მხოლოდ ადმინისტრატორს აქვს. როცა ყველასთვის გაიხსნება, აქვე გამოჩნდება.</p><button class="btn" data-a="glockhome">${ic('home')}მთავარზე დაბრუნება</button></div></div>`;
A.glockhome=()=>go('home');
/* the games tab: the lock page, or the tab without what is switched off */
{const rg=R.games;R.games=function(...a){if(gLocked()){S.game=null;view.innerHTML=gLockHTML();return}const r=rg.apply(this,a);if(!S.game&&!S.page&&S.tab==='games')gHideOff();return r}}
function gHideOff(){if(gAdm())return;const rm=sel=>$$(sel,view).forEach(x=>x.remove());
 GGROUPS[0][2].forEach(([id])=>{if(gOff(id))rm(`.gs-post[data-g="${id}"]`)});
 /* the big card first in the shelf: the first game still on takes its place */
 const sh=$('.gs-shelf',view);if(sh&&!$('.gs-post.big',sh)){const f=$('.gs-post',sh);if(f)f.classList.add('big')}if(sh&&!$('.gs-post',sh))sh.innerHTML=`<p class="hint glock-none">სამაგიდო თამაშები დროებით გამორთულია.</p>`;
 if(gOff('career'))rm('[data-p="career"]');if(gOff('daily'))rm('[data-a="gdaily"]');if(gOff('puzzles'))rm('[data-a="pzplay"],[data-a="sprint"]');
 if(gOff('corrs'))rm('[data-p="corrs"]');if(gOff('cups'))rm('[data-p="cups"]');if(gOff('tables'))rm('[data-a="gtablepick"]');if(gOff('tour'))rm('.gs-tour,[data-p="tour"]')}
{const gh=gHub;gHub=function(...a){if(gLocked()){go('games');return}return gh.apply(this,a)}}
{const sg=startGame;startGame=function(id,ctx,...a){if(gLocked()){toast('თამაშები დროებით მხოლოდ ადმინისტრატორისთვისაა');if(S.tab!=='games'||S.page)go('games');return}
 if(gOff(id)){gOffMsg(id);if(S.tab!=='games'||S.page)go('games');return}
 if(ctx&&ctx.daily&&gOff('daily')){gOffMsg('daily');return}if(ctx&&ctx.mode==='puzzle'&&gOff('puzzles')){gOffMsg('puzzles');return}return sg.call(this,id,ctx,...a)}}
{const op=openPage;openPage=function(id,...a){if(gLocked()&&GLOCK_PAGES.includes(id)){go('games');return}
 const g=GPAGE_G[id];if(g&&gOff(g)){gOffMsg(g);return}if(id==='gkind'&&gGroupOff(a[0])){toast('ეს თამაშები დროებით გამორთულია');return}return op.call(this,id,...a)}}
/* the ways into the online tables, the daily hand and the sprint */
for(const[a,g]of[['jkonew','tables'],['dmonew','tables'],['lotnew','tables'],['gtablepick','tables'],['gdaily','daily'],['sprint','puzzles'],['pzplay','puzzles']]){const f=A[a];if(f)A[a]=function(...x){if(gLocked()||gOff(g)){gLocked()?toast('თამაშები დროებით მხოლოდ ადმინისტრატორისთვისაა'):gOffMsg(g);return}return f.apply(this,x)}}
/* new settings: what is on screen follows (the games tab, the chooser) */
function gCtlApply(){try{if(S.tab==='games'&&!S.page&&!S.game)R.games();else if(S.game&&gOff(S.game)&&!gAdm()){toast(`${GG_N[S.game]||'ეს თამაში'} გამოირთო`)}}catch(e){}}
