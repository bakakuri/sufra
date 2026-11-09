/* the games are for the admin only for now: everyone else finds one page saying they are closed, and nothing in them opens
   (the games tab, the chooser, a game, the casino, the online tables, cups, tournaments, the career, replays).
   The server keeps the same lock for the casino (app_settings games_lock). To open them for everyone: GLOCK_ON = false */
const GLOCK_ON=true;
const gLocked=()=>GLOCK_ON&&!(ME&&ME.role==='admin');
const GLOCK_PAGES=['slot','fleece','batumi','roulette','bj','aviator','mines','plinko','gkind','jktable','dmtable','lotable','career','corrs','cup','cups','replay','tour'];
const gLockHTML=()=>`<div class="view-pad glock"><div class="glock-c"><span class="glock-i">${ic('lock')}</span><h2>თამაშები დროებით შეზღუდულია</h2><p>თამაშებზე წვდომა ამჟამად მხოლოდ ადმინისტრატორს აქვს. როცა ყველასთვის გაიხსნება, აქვე გამოჩნდება.</p><button class="btn" data-a="glockhome">${ic('home')}მთავარზე დაბრუნება</button></div></div>`;
A.glockhome=()=>go('home');
{const rg=R.games;R.games=function(...a){if(gLocked()){S.game=null;view.innerHTML=gLockHTML();return}return rg.apply(this,a)}}
{const gh=gHub;gHub=function(...a){if(gLocked()){go('games');return}return gh.apply(this,a)}}
{const sg=startGame;startGame=function(...a){if(gLocked()){toast('თამაშები დროებით მხოლოდ ადმინისტრატორისთვისაა');if(S.tab!=='games'||S.page)go('games');return}return sg.apply(this,a)}}
{const op=openPage;openPage=function(id,...a){if(gLocked()&&GLOCK_PAGES.includes(id)){go('games');return}return op.call(this,id,...a)}}
