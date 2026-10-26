/* ---------- games for everyone: moves said aloud, boards played from a keyboard, colours that stand apart ----------
   the other side's moves are told in words to the screen reader (and spoken by the phone's Georgian voice when it has one
   and the switch is on); on a flat board the arrow keys walk from square to square and Enter plays; the contrast switch
   gives the flat boards, the pieces and the cards stronger colours and turns on the four-colour deck */
const gSpkOn=()=>!!store.get('gspk',false);
const gHcOn=()=>!!store.get('ghc',false);
try{document.documentElement.classList.toggle('ghc',gHcOn())}catch(e){}
A.gspkt=t=>{const on=!gSpkOn();store.set('gspk',on);gSwFlip(t,on);if(on){gSay2('სვლების გახმოვანება ჩართულია');if(typeof lotoVoice==='function'&&!lotoVoice())toast('ეკრანის წამკითხველი სვლებს წაიკითხავს. ამ ტელეფონს ქართული ხმა არ აქვს')}};
A.ghct=t=>{const on=!gHcOn();store.set('ghc',on);document.documentElement.classList.toggle('ghc',on);if(on&&!c4On()){store.set('c4',true);document.documentElement.classList.add('c4')}gSwFlip(t,on);gRedraw()};
/* one sentence for the screen reader, and for the voice when asked */
function gSay2(txt){let el=$('#garia');if(!el){el=document.createElement('div');el.id='garia';el.className='sr';el.setAttribute('aria-live','assertive');document.body.appendChild(el)}el.textContent='';setTimeout(()=>{el.textContent=txt},30);
 if(!gSpkOn()||typeof window.speechSynthesis==='undefined')return;const v=typeof lotoVoice==='function'&&lotoVoice();if(!v)return;try{window.speechSynthesis.cancel();const u=new window.SpeechSynthesisUtterance(txt);u.voice=v;u.lang=v.lang;window.speechSynthesis.speak(u)}catch(e){}}
const SQN=i=>'abcdefgh'[i&7]+(8-(i>>3));
/* chess: the piece, where it went, a capture, check and mate */
{const rn=CH.render;CH.render=function(...a){const r=rn.apply(this,a);const st=this.st,c=this.ctx;if(!st||!c||S.game!=='chess'||!st.last||st.last.length!==2)return r;const key=st.b.join('')+st.turn;if(this.saidK===key)return r;const first=this.saidK==null;this.saidK=key;
  if(first||!(gSpkOn()||document.activeElement&&document.activeElement.closest&&document.activeElement.closest('.cb')))return r;
  const[f,t]=st.last,p=st.b[t];if(!p)return r;const who=colOf(p)===c.side&&isPlayer(c)&&c.mode!=='local'?'შენ':colOf(p)===1?'თეთრი':'შავი',cap=this.ps&&this.ps!==st&&this.ps.b&&this.ps.b[t]?', იღებს':'';
  const chk=st.over?(st.why==='mate'||st.over!==2?' მატი!':''):chInChk(st)?' ქიში!':'';gSay2(`${who}: ${PNAME[p.toLowerCase()]} ${SQN(f)}-დან ${SQN(t)}-ზე${cap}.${chk}`);return r}}
/* checkers: from where to where, and how many taken */
{const pl=CK.play;CK.play=function(m){const side=this.turn,r=pl.call(this,m);if(m&&m.path&&(gSpkOn()||document.activeElement&&document.activeElement.closest&&document.activeElement.closest('.cb,.ckb'))){const sq=x=>'abcdefgh'[x[1]]+(8-x[0]),n=m.cap?m.cap.length:0;
  gSay2(`${side===this.ctx.side&&isPlayer(this.ctx)&&this.ctx.mode!=='local'?'შენ':side===1?'თეთრი':'შავი'}: ${m.path.map(sq).join(n?' ჭრით ':'-დან ')}${n?'':'-ზე'}${n>1?`, ${n} ქვა`:n?', ერთი ქვა':''}`)}return r}}
/* nardi: the dice and the checkers' steps of the turn just ended */
{const et=NR.endTurn;NR.endTurn=function(){const s=this.turn,a=this.alog&&this.alog[this.alog.length-1],d=this.dice0||this.last;const r=et.call(this);
  if(gSpkOn()&&a&&a.s===s&&a.mv){const me=s===this.ctx.side&&this.ctx.mode!=='local';gSay2(`${me?'შენ':s===1?'თეთრი':'შავი'}: ${a.dice.join(' და ')}. ${a.mv.map(x=>nPtNo(this,x.f)+'-დან '+nPtNo(this,x.to)).join(', ')||'სვლა არ იყო'}`)}return r}}
/* cards: whatever lands on the table */
{const pc=JK.playCard;JK.playCard=function(p,c,jm,js){const r=pc.call(this,p,c,jm,js);if(gSpkOn()&&this===JK&&p!==0)gSay2(`${this.nm(p)}: ${cardName(c)}${c.j?(jm==='lo'?', დაბალი':', მაღალი'):''}`);return r}}
{const pl=DK.play;DK.play=function(p,c){const ph=this.phase,r=pl.call(this,p,c);if(r&&gSpkOn()&&p!==0)gSay2(`${this.nm(p)} ${ph==='def'?'ფარავს':'დადო'}: ${cardName(c)}`);return r}}
/* the arrow keys on a flat board: to the nearest square in that direction, as it is drawn on the screen */
document.addEventListener('keydown',e=>{const k=e.key;if(!['ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(k))return;const a=document.activeElement,b=a&&a.closest&&a.closest('.cb,.ckb,.nb,.ltg,.hand,.dmhand,.ebasket');if(!b)return;
 const items=[...b.querySelectorAll('button:not([disabled]),[tabindex="0"]')].filter(x=>x.offsetParent);if(items.length<2)return;e.preventDefault();
 const r0=a.getBoundingClientRect(),cx=r0.left+r0.width/2,cy=r0.top+r0.height/2,dx=k==='ArrowLeft'?-1:k==='ArrowRight'?1:0,dy=k==='ArrowUp'?-1:k==='ArrowDown'?1:0;let best=null,bv=1e9;
 for(const it of items){if(it===a)continue;const r=it.getBoundingClientRect(),x=r.left+r.width/2-cx,y=r.top+r.height/2-cy,along=x*dx+y*dy;if(along<=2)continue;const across=Math.abs(x*dy)+Math.abs(y*dx),v=along+across*2.5;if(v<bv){bv=v;best=it}}
 if(best)best.focus()},true);
/* disabled squares stay reachable by keyboard on the chess board, so a player can look around */
{const rn=CH.render;CH.render=function(...a){const r=rn.apply(this,a);if(S.game==='chess'&&!S.page){const b=$('.cb',view);if(b)b.querySelectorAll('button[disabled]').forEach(x=>{x.removeAttribute('disabled');x.setAttribute('aria-disabled','true')})}return r}}
