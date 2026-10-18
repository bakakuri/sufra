/* ---------- motion: transitions, reveals, feedback ---------- */
const RM=()=>{try{return matchMedia('(prefers-reduced-motion: reduce)').matches}catch(e){return false}};
const EASE='cubic-bezier(.22,1,.36,1)',SPRING='cubic-bezier(.34,1.56,.64,1)';
const anim=(el,kf,o)=>{if(!el||RM()||!el.animate)return null;try{return el.animate(kf,o)}catch(e){return null}};
function staggerIn(els,step=45,delay=30){els.forEach((el,i)=>anim(el,[{opacity:0,translate:'0 16px'},{opacity:1,translate:'0 0'}],{duration:480,delay:delay+i*step,easing:EASE,fill:'backwards'}))}
const REVEAL='.post,.evcard,.gcard,.mitem,.lcard,.tile,.orow,.chpost,.list>.row,.rrow,.lgcard,.pgrid img,.tourcard,.ghero,.vcard,.setrow,.hist>div';
function enterView(dx){anim(view,[{opacity:0,translate:`${dx}px 0`},{opacity:1,translate:'0 0'}],{duration:360,easing:EASE});
 staggerIn($$(REVEAL,view).filter(el=>el.getBoundingClientRect().top<innerHeight).slice(0,9))}
function moveInd(i){const t=$('.tabind');if(t)t.style.transform=`translateX(${i*100}%)`}
function burst(el,color){if(!el||RM())return;const r=el.getBoundingClientRect(),cx=r.left+r.width/2,cy=r.top+r.height/2,cols=color?[color]:['#EC5A88','#EDB54A','#A8164A','#55C08C'];
 for(let i=0;i<10;i++){const d=document.createElement('i');d.className='spark';d.style.left=cx+'px';d.style.top=cy+'px';d.style.background=cols[i%cols.length];document.body.appendChild(d);
  const a=i/10*Math.PI*2+Math.random()*.4,dist=26+Math.random()*20;
  const an=anim(d,[{transform:'translate(-50%,-50%) scale(1)',opacity:1},{transform:`translate(calc(-50% + ${Math.cos(a)*dist}px),calc(-50% + ${Math.sin(a)*dist}px)) scale(.2)`,opacity:0}],{duration:620,easing:EASE});
  if(an)an.onfinish=()=>d.remove();else d.remove()}}
const pop=el=>anim(el,[{transform:'scale(1)'},{transform:'scale(1.32)'},{transform:'scale(1)'}],{duration:440,easing:SPRING});
function confetti(){if(RM())return;const c=document.createElement('canvas');c.className='confetti';c.setAttribute('aria-hidden','true');document.body.appendChild(c);
 const W=c.width=innerWidth,H=c.height=innerHeight,x=c.getContext('2d'),cols=['#EC5A88','#EDB54A','#55C08C','#3E8EF7','#A8164A','#FFFFFF'];
 const ps=Array.from({length:150},()=>({x:W/2+(Math.random()-.5)*W*.35,y:H*.38,vx:(Math.random()-.5)*15,vy:-Math.random()*15-4,r:Math.random()*7+4,c:cols[Math.floor(Math.random()*cols.length)],a:Math.random()*6,va:(Math.random()-.5)*.35}));
 const t0=performance.now();(function f(t){const k=(t-t0)/1000;x.clearRect(0,0,W,H);for(const p of ps){p.vy+=.38;p.vx*=.99;p.x+=p.vx;p.y+=p.vy;p.a+=p.va;x.save();x.translate(p.x,p.y);x.rotate(p.a);x.globalAlpha=Math.max(0,1-k/2.4);x.fillStyle=p.c;x.fillRect(-p.r/2,-p.r/4,p.r,p.r/2);x.restore()}
  if(k<2.4)requestAnimationFrame(f);else c.remove()})(t0)}
function animNum(el,a,b){if(RM()||a===b){el.textContent=b;return}const t0=performance.now();(function f(t){const k=Math.min(1,(t-t0)/650),e=1-Math.pow(1-k,3);el.textContent=Math.round(a+(b-a)*e);if(k<1)requestAnimationFrame(f)})(t0)}
function flipPiece(from,to){if(!from||!to)return;const p=to.firstElementChild;if(!p)return;const a=from.getBoundingClientRect(),b=to.getBoundingClientRect();
 anim(p,[{transform:`translate(${a.left-b.left}px,${a.top-b.top}px)`,zIndex:5},{transform:'none',zIndex:5}],{duration:300,easing:EASE})}
function dragSheet(p){if(!p)return;let y0=null,dy=0;
 p.addEventListener('pointerdown',e=>{const r=p.getBoundingClientRect();if(e.clientY-r.top>60||e.target.closest('button,input,textarea,select,a,label'))return;y0=e.clientY;dy=0;try{p.setPointerCapture(e.pointerId)}catch(_){}p.style.transition='none';p.style.animation='none'});
 p.addEventListener('pointermove',e=>{if(y0===null)return;dy=Math.max(0,e.clientY-y0);p.style.transform=`translateY(${dy}px)`});
 const up=()=>{if(y0===null)return;y0=null;p.style.transition='transform .3s cubic-bezier(.22,1,.36,1)';if(dy>90){p.style.transform='translateY(105%)';closeSheet()}else p.style.transform=''};
 p.addEventListener('pointerup',up);p.addEventListener('pointercancel',up)}

