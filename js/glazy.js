/* games, casino and the admin panel come only when first needed (they are about 40% of all the code): the games tab, a game page,
   a game started from a chat, a challenge or a notification, the admin panel, or an action of theirs touched before they came.
   What everyone needs stays in the first load: the game list and lobby presence (online friends, challenges), game messages
   in chats, cups. The files come in their old order, one after another, from the same version as the page */
const GLZ={files:['games-engines','domino','cards2','games-modes','loto','egg','joker-online','joker-more','domino-online','gvoice','games-side','corr','gstudy','glive','gquest','ghub','casino','cs-slot','cs-table','cs-fast','gaccess','glock'],p:null,ready:false,adm:null};
const GLZ_PG=['admin','aviator','bj','career','corrs','dmtable','gkind','jktable','lotable','mines','plinko','replay','roulette','slot','fleece','batumi'];
function glScripts(files){const v=(($('script[src*="/js/core.js"]')||{}).src||'').split('v=')[1]||'';
 return new Promise((res,rej)=>{let left=files.length,bad=false;
  for(const f of files){const s=document.createElement('script');s.src=`/js/${f}.js${v?'?v='+v:''}`;s.async=false;
   s.onload=()=>{if(!bad&&!--left)res()};s.onerror=()=>{if(bad)return;bad=true;rej(new Error('load '+f))};document.head.appendChild(s)}})}
function glLoad(){if(GLZ.ready)return Promise.resolve();if(GLZ.p)return GLZ.p;
 GLZ.p=glScripts(GLZ.files).then(()=>{GLZ.ready=true;try{if(typeof gCtlApply==='function')gCtlApply()}catch(e){}},e=>{GLZ.p=null;throw e});return GLZ.p}
/* the admin panel: for the admin only, after the games (its games tab uses them) */
function glAdmin(){if(PG.admin)return Promise.resolve();if(GLZ.adm)return GLZ.adm;GLZ.adm=glLoad().then(()=>glScripts(['admin'])).catch(e=>{GLZ.adm=null;throw e});return GLZ.adm}
/* on a good connection the games come a few seconds after the start anyway, in the background, so the tab opens at once */
function glPrefetch(){try{const c=navigator.connection;if(c&&(c.saveData||/(^|-)2g$/.test(c.effectiveType||'')))return}catch(e){}
 const go2=()=>{if(!GLZ.ready&&!GLZ.p)glLoad().catch(()=>{})};if(window.requestIdleCallback)window.requestIdleCallback(go2,{timeout:8000});else setTimeout(go2,2500)}
/* while they come: a spinner where the screen will be; if they cannot come, a way to try again */
function glWait(then,where){const el=where||view;GLZ.retry=()=>glWait(then,where);if(el&&!GLZ.ready)el.innerHTML='<div class="view-pad glz" aria-busy="true"><span class="spin" aria-label="იტვირთება"></span></div>';
 return glLoad().then(then).catch(()=>{if(el)el.innerHTML=`<div class="view-pad">${empty('ვერ ჩაიტვირთა','შეამოწმე ინტერნეტი და სცადე ისევ.','<button class="btn" data-a="glzretry">თავიდან ცდა</button>')}</div>`})}
A.glzretry=()=>{const f=GLZ.retry;GLZ.retry=null;if(f)f();else go(S.tab||'home')};
/* the games tab */
{const r0=R.games;R.games=function(...a){if(!GLZ.ready){glWait(()=>{if(S.tab==='games'&&!S.page)R.games(...a)});return}return r0.apply(this,a)}}
/* the games button in the tab bar and the side menu (the hub of game kinds) */
function gOpenHub(){if(GLZ.ready&&typeof gHub==='function'){gHub();return}glLoad().then(()=>{if(typeof gHub==='function')gHub()}).catch(()=>toast('თამაშები ვერ ჩაიტვირთა. შეამოწმე ინტერნეტი'))}
/* a game started from anywhere: a chat card, a challenge, a notification */
{const sg=startGame;startGame=function(...a){if(!GLZ.ready){glWait(()=>startGame(...a));return}return sg.apply(this,a)}}
/* a page of theirs: a game table, the casino, the admin panel */
{const op=openPage;openPage=function(id,...a){if(!PG[id]&&GLZ_PG.includes(id)){if(id==='admin'){glAdmin().then(()=>openPage(id,...a)).catch(()=>toast('ვერ ჩაიტვირთა. შეამოწმე ინტერნეტი'));return}if(!GLZ.ready){glWait(()=>openPage(id,...a));return}}return op.call(this,id,...a)}}
