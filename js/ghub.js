/* the games button opens a chooser of four kinds: slots, table games, casino, fast games.
   table games are the lobby that was there before; each other kind has a page with its games.
   slots, casino and the aviator are played on coins (js/casino.js) and only by adults: a minor does not see them */
const GKINDS=[
 {k:'slots',n:'სლოტები',d:'ქართული სლოტი',adult:1},
 {k:'board',n:'სამაგიდო თამაშები',d:'ნარდი, ჭადრაკი, ჯოკერი, დომინო და სხვა'},
 {k:'casino',n:'კაზინო',d:'რულეტკა და ბლექჯეკი',adult:1},
 {k:'fast',n:'სწრაფი თამაშები',d:'ავიატორი და კვერცხის ჭახუნი'}];
/* the games of each kind: the egg game is a board-style game, the others are casino pages */
const GKGAMES={
 slots:[{id:'slot',n:'ქართული სლოტი',d:'ღვინო, ყურძენი, ხაჭაპური, ჩურჩხელა, ყანწი და შვიდიანები',adult:1,art:'slots'}],
 casino:[{id:'roulette',n:'რულეტკა',d:'ევროპული ბორბალი, ერთი ნულით',adult:1,art:'casino'},{id:'bj',n:'ბლექჯეკი',d:'21: შენ დილერის წინააღმდეგ',adult:1,art:'bj'}],
 fast:[{id:'aviator',n:'ავიატორი',d:'თვითმფრინავი მაღლა მიფრინავს: აიღე, სანამ გაფრინდება',adult:1,art:'fast'},{id:'egg',n:'კვერცხის ჭახუნი',d:'',img:1}]};
const gkVisible=()=>{const ad=isAdult();return GKINDS.filter(k=>!k.adult||ad).map(k=>({...k,d:k.k==='fast'&&!ad?'კვერცხის ჭახუნი':k.d,games:(GKGAMES[k.k]||[]).filter(g=>!g.adult||ad)}))};

/* drawn pictures for the kinds that have no board art yet */
function hubRoulette(){const cx=100,cy=76,P=(r,a)=>`${(cx+r*Math.cos(a)).toFixed(2)} ${(cy+r*Math.sin(a)).toFixed(2)}`,n=18;let seg='';
 for(let i=0;i<n;i++){const a0=i/n*2*Math.PI-Math.PI/2,a1=(i+1)/n*2*Math.PI-Math.PI/2;
  seg+=`<path d="M${P(53,a0)}A53 53 0 0 1 ${P(53,a1)}L${P(35,a1)}A35 35 0 0 0 ${P(35,a0)}Z" fill="${i===0?'#0E8A4B':i%2?'#C8102E':'#16161A'}"/>`}
 return `<svg class="hub-art" viewBox="0 0 200 150" aria-hidden="true"><defs><radialGradient id="hbrw" cx=".5" cy=".5" r=".5"><stop offset=".7" stop-color="#7A3E12"/><stop offset="1" stop-color="#3B1A06"/></radialGradient>
 <radialGradient id="hbrc" cx=".4" cy=".35" r=".7"><stop offset="0" stop-color="#9B5A26"/><stop offset="1" stop-color="#4A2208"/></radialGradient><linearGradient id="hbrg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFF0B8"/><stop offset=".5" stop-color="#E9B44C"/><stop offset="1" stop-color="#9A6612"/></linearGradient></defs>
 <ellipse cx="100" cy="142" rx="66" ry="6" fill="#000" opacity=".28"/><circle cx="${cx}" cy="${cy}" r="63" fill="url(#hbrw)"/><circle cx="${cx}" cy="${cy}" r="56" fill="none" stroke="url(#hbrg)" stroke-width="3"/>
 <g class="hub-spin">${seg}<circle cx="${cx}" cy="${cy}" r="35" fill="url(#hbrc)"/>${[0,1,2,3].map(i=>`<path d="M${P(4,i*Math.PI/2)}L${P(24,i*Math.PI/2)}" stroke="url(#hbrg)" stroke-width="3" stroke-linecap="round"/>`).join('')}<circle cx="${cx}" cy="${cy}" r="9" fill="url(#hbrg)"/></g>
 <circle cx="${(cx+44*Math.cos(-0.5)).toFixed(1)}" cy="${(cy+44*Math.sin(-0.5)).toFixed(1)}" r="4.5" fill="#fff" stroke="#bbb" stroke-width=".8"/>
 <g transform="translate(160 122)"><circle r="14" fill="#1F5FE0"/><circle r="14" fill="none" stroke="#fff" stroke-width="3" stroke-dasharray="4 5.2"/><circle r="8" fill="#2F6BFF" stroke="#fff" stroke-opacity=".6"/></g>
 <g transform="translate(176 106)"><circle r="12" fill="#C8102E"/><circle r="12" fill="none" stroke="#fff" stroke-width="2.6" stroke-dasharray="3.6 4.3"/><circle r="6.5" fill="#E0243B" stroke="#fff" stroke-opacity=".6"/></g></svg>`}
const HUBART={
 slots:()=>`<svg class="hub-art" viewBox="0 0 200 150" aria-hidden="true"><defs><linearGradient id="hbsg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFE9A8"/><stop offset=".45" stop-color="#F0B03E"/><stop offset="1" stop-color="#A9650F"/></linearGradient>
 <linearGradient id="hbsr" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#C9C2DA"/><stop offset=".3" stop-color="#fff"/><stop offset=".7" stop-color="#fff"/><stop offset="1" stop-color="#C9C2DA"/></linearGradient><radialGradient id="hbsb" cx=".35" cy=".35" r=".7"><stop offset="0" stop-color="#FF8A9A"/><stop offset="1" stop-color="#C8102E"/></radialGradient></defs>
 <ellipse cx="94" cy="142" rx="70" ry="6" fill="#000" opacity=".28"/><path class="hub-lever" d="M166 92V48" stroke="#E4DEEF" stroke-width="5" stroke-linecap="round"/><circle class="hub-lever" cx="166" cy="44" r="9" fill="url(#hbsb)"/><rect x="152" y="84" width="16" height="18" rx="5" fill="#8B5A12"/>
 <rect x="30" y="24" width="126" height="112" rx="18" fill="url(#hbsg)"/><rect x="38" y="31" width="110" height="23" rx="9" fill="#4A0E3C"/><text x="93" y="47.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#FFD66B">ჯეკპოტი</text>
 ${[0,1,2,3,4,5,6,7].map(i=>`<circle class="hub-bulb" style="--d:${i*.15}s" cx="${44+i*14.2}" cy="58.5" r="2.1" fill="#FFF6D8"/>`).join('')}
 <rect x="40" y="63" width="106" height="52" rx="10" fill="#2B0A26"/>${[46,79,112].map(x=>`<rect x="${x}" y="68" width="28" height="42" rx="6" fill="url(#hbsr)"/>`).join('')}
 <text x="60" y="97" text-anchor="middle" font-size="21">🍇</text><text x="93" y="99" text-anchor="middle" font-size="27" font-weight="900" fill="#E0243B">7</text><text x="126" y="97" text-anchor="middle" font-size="21">🍷</text>
 <path d="M43 89H143" stroke="#FF3B5C" stroke-width="1.6" opacity=".75"/><rect x="79" y="121" width="28" height="6" rx="3" fill="#7A4A0C"/></svg>`,
 casino:hubRoulette,
 fast:()=>`<svg class="hub-art" viewBox="0 0 200 150" aria-hidden="true"><defs><linearGradient id="hbaf" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FF3B5C" stop-opacity=".55"/><stop offset="1" stop-color="#FF3B5C" stop-opacity="0"/></linearGradient></defs>
 ${[[24,18],[60,30],[120,14],[150,62],[96,48],[182,20],[40,70]].map(([x,y],i)=>`<circle cx="${x}" cy="${y}" r="${i%3?1:1.5}" fill="#fff" opacity=".55"/>`).join('')}
 ${[40,80,120].map(y=>`<path d="M8 ${y}H192" stroke="#fff" stroke-opacity=".07"/>`).join('')}
 <path d="M30 120Q120 114 166 40L166 120Z" fill="url(#hbaf)"/><path d="M30 120Q120 114 166 40" fill="none" stroke="#FF3B5C" stroke-width="4" stroke-linecap="round"/>
 <g class="hub-plane"><g transform="translate(170 33) rotate(-58) scale(1.2)"><path d="M-2-2.5L-9-17H-3.5L7-2.5Z" fill="#C8102E"/><path d="M-2 2.5L-9 17H-3.5L7 2.5Z" fill="#C8102E"/><path d="M-15-2L-20-8H-17L-11-2Z" fill="#C8102E"/><path d="M-15 2L-20 8H-17L-11 2Z" fill="#C8102E"/><path d="M-18-2.4L10-3.2Q19 0 10 3.2L-18 2.4Z" fill="#FF4D6A"/><path d="M8-1.6Q13 0 8 1.6Z" fill="#fff" opacity=".7"/></g></g>
 <text x="16" y="44" font-size="30" font-weight="900" fill="#fff" letter-spacing="-1">2.37×</text></svg>`,
 bj:()=>`<svg class="hub-art" viewBox="0 0 200 150" aria-hidden="true"><ellipse cx="100" cy="140" rx="60" ry="6" fill="#000" opacity=".28"/>
 <g transform="translate(78 74) rotate(-12)"><rect x="-30" y="-42" width="60" height="84" rx="8" fill="#fff" stroke="#d8d8d8"/><text x="-21" y="-23" font-size="17" font-weight="800" fill="#16161A">A</text><text x="0" y="14" text-anchor="middle" font-size="38" fill="#16161A">♠</text></g>
 <g transform="translate(122 72) rotate(10)"><rect x="-30" y="-42" width="60" height="84" rx="8" fill="#fff" stroke="#d8d8d8"/><text x="-21" y="-23" font-size="17" font-weight="800" fill="#C8102E">K</text><text x="0" y="14" text-anchor="middle" font-size="38" fill="#C8102E">♥</text></g>
 <g transform="translate(162 120)"><circle r="14" fill="#16161A"/><circle r="14" fill="none" stroke="#E9B44C" stroke-width="3" stroke-dasharray="4 5.2"/><text y="4.5" text-anchor="middle" font-size="12" font-weight="900" fill="#E9B44C">21</text></g></svg>`};

function hubPic(k){if(k==='board'||k==='fast'&&!isAdult())return `<img class="hub-img" src="${GART(k==='board'?'nardi':'egg',600)}" alt="" decoding="async">`;return (HUBART[k]||HUBART.slots)()}
function hubCard(k,i){
 return `<button class="hub-k hub-${k.k}" style="--i:${i}" data-a="gkind" data-k="${k.k}" aria-label="${k.n}. ${k.d}${k.soon?'. მალე':''}"><span class="hub-pic">${hubPic(k.k)}</span>
 <span class="hub-tx"><b>${k.n}</b><small>${k.d}</small></span>${k.soon?'<em class="hub-soon">მალე</em>':`<em class="hub-n">${k.k==='board'?GAMES.filter(g=>g.id!=='egg').length:k.games.length} თამაში</em>`}${k.adult?'<i class="hub-18" aria-hidden="true">18+</i>':''}</button>`}

/* the chooser: a sheet, so the back button closes it and leaves the person where they were */
function gHub(){if(typeof tabOk==='function'&&!tabOk('games')){go('games');return}
 const last=store.get('glast',null),lg=GAMES.find(g=>g.id===last);
 sheet(head('თამაშები')+`<div class="hub"><p class="hub-sub">აირჩიე, რა ითამაშო</p><div class="hub-grid">${gkVisible().map(hubCard).join('')}</div>
  ${lg?`<button class="hub-last" data-a="gkplay" data-g="${lg.id}"><img src="${GART(lg.id,600)}" alt="" loading="lazy" decoding="async"><span class="grow"><small>ბოლოს ითამაშე</small><b>${lg.n}</b></span><span class="btn sm gold">${ic('play')}${gSaved(lg.id)?'გაგრძელება':'თამაში'}</span></button>`:''}</div>`,'short hubp')}
A.gkind=t=>{const k=t.dataset.k;closeSheet();if(k==='board'){go('games');return}openPage('gkind',k)};
const GK_PAGES=['slot','roulette','bj','aviator'];
A.gkplay=t=>{const id=t.dataset.g,g=[...GAMES,...Object.values(GKGAMES).flat()].find(x=>x.id===id);if(!g)return;
 if(GK_PAGES.includes(id)&&PG[id]){closeSheet();openPage(id);return}
 if(g.soon||!GAME[id]){toast(`${g.n} მალე დაემატება`);return}closeSheet();A.play(t)};

/* a kind's own page: the big picture, then its games */
PG.gkind={r(k){const K=gkVisible().find(x=>x.k===k);if(k==='board'){go('games');return}
 if(!K){view.innerHTML=pgHead('თამაშები')+empty('ეს თამაშები 18 წლიდანაა','');return}
 view.innerHTML=pgHead(K.n)+`<div class="view-pad hubpg"><div class="hub-hero hub-${k}"><span class="hub-pic">${hubPic(k)}</span><span class="hub-tx"><b>${K.n}</b><small>${K.d}</small></span>${K.adult?'<i class="hub-18" aria-hidden="true">18+</i>':''}</div>
 <div class="hub-list">${K.games.map((g,i)=>{const eg=g.img&&GAMES.find(x=>x.id===g.id);return `<button class="hub-g" style="--i:${i}" data-a="gkplay" data-g="${g.id}"><span class="hub-th hub-${g.art||'plain'}">${eg?`<img src="${GART(g.id,600)}" alt="" loading="lazy" decoding="async">`:hubPic(g.art)}</span>
  <span class="grow"><b>${g.n}</b><small>${esc(g.d||eg?.d||'')}</small></span>${g.soon?'<em class="hub-soon">მალე</em>':`<span class="btn sm gold">${ic('play')}თამაში</span>`}</button>`}).join('')}</div>
 ${K.adult||K.games.some(g=>g.adult)?`<p class="note hub-note">${ic('lock')}<span>${K.k==='fast'?'ავიატორი':'ეს თამაშები'} მხოლოდ 18 წლიდანაა.</span></p>`:''}</div>`}};
