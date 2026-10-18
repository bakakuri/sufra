/* icons + generated illustrations */
const IC={
 home:'<path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z"/>',
 clips:'<rect x="4" y="3" width="16" height="18" rx="4"/><path d="M10 9l5 3-5 3z"/>',
 heart:'<path d="M12 20s-7-4.4-9-9a5 5 0 0 1 9-3 5 5 0 0 1 9 3c-2 4.6-9 9-9 9z"/>',
 dice:'<rect x="3" y="3" width="18" height="18" rx="4"/><circle cx="8.5" cy="8.5" r="1.3" fill="currentColor"/><circle cx="12" cy="12" r="1.3" fill="currentColor"/><circle cx="15.5" cy="15.5" r="1.3" fill="currentColor"/>',
 user:'<circle cx="12" cy="8" r="4"/><path d="M4 21c1-4 4.5-6 8-6s7 2 8 6"/>',
 msg:'<path d="M4 5h16v11H9l-5 4z"/>',
 bell:'<path d="M6 16v-5a6 6 0 0 1 12 0v5l2 2H4z"/><path d="M10 20a2 2 0 0 0 4 0"/>',
 x:'<path d="M6 6l12 12M18 6L6 18"/>',
 star:'<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>',
 comment:'<path d="M20 12a8 8 0 0 1-11.6 7.1L4 20l1-4A8 8 0 1 1 20 12z"/>',
 repost:'<path d="M7 7h11l-3-3M17 17H6l3 3"/>',
 send:'<path d="M4 12l16-8-6 16-3-7z"/>',
 back:'<path d="M15 5l-7 7 7 7"/>',
 pin:'<path d="M12 21s7-6.5 7-12a7 7 0 0 0-14 0c0 5.5 7 12 7 12z"/><circle cx="12" cy="9" r="2.5"/>',
 gift:'<rect x="3" y="8" width="18" height="13" rx="2"/><path d="M12 8v13M3 12h18M12 8c-2-4-6-4-6-1s6 1 6 1zm0 0c2-4 6-4 6-1s-6 1-6 1z"/>',
 note:'<path d="M9 18V5l11-2v13"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="17.5" cy="16" r="2.5"/>',
 eye:'<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
 school:'<path d="M2 9l10-5 10 5-10 5z"/><path d="M6 11v5c3 2 9 2 12 0v-5"/>',
 checker:'<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4.5"/>',
 chess:'<path d="M7 20h10M8.5 20c0-3.5 1-5.5 3-7.5-2.5 0-4-1.2-4-3 2-1 3-4.5 7-4.5 2.5 2.5 2.5 7 .5 9.5l1 5.5"/>',
 cards:'<rect x="4" y="5" width="11" height="15" rx="2"/><path d="M15 7l4.5 1.2-3 12-3-.8"/>',
 domino:'<rect x="7" y="2" width="10" height="20" rx="2"/><path d="M7 12h10"/><circle cx="12" cy="7" r="1.2" fill="currentColor"/><circle cx="10" cy="15.5" r="1.2" fill="currentColor"/><circle cx="14" cy="18.5" r="1.2" fill="currentColor"/>',
 globe:'<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3.2 3 14.8 0 18M12 3c-3 3.2-3 14.8 0 18"/>',
 coin:'<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5.5"/><path d="M12 9.5v5"/>',
 phone:'<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z"/>',
 video:'<rect x="3" y="6" width="13" height="12" rx="2"/><path d="M16 10l5-3v10l-5-3z"/>',
 mic:'<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>',
 micoff:'<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 11 5.7M12 18v3M4 4l16 16"/>',
 more:'<circle cx="5" cy="12" r="1.3" fill="currentColor"/><circle cx="12" cy="12" r="1.3" fill="currentColor"/><circle cx="19" cy="12" r="1.3" fill="currentColor"/>',
 grid:'<rect x="4" y="4" width="6" height="6" rx="1.5"/><rect x="14" y="4" width="6" height="6" rx="1.5"/><rect x="4" y="14" width="6" height="6" rx="1.5"/><rect x="14" y="14" width="6" height="6" rx="1.5"/>',
 cal:'<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>',
 store:'<path d="M3 9l2-5h14l2 5"/><path d="M4 9v11h16V9M3 9h18M9 20v-6h6v6"/>',
 live:'<circle cx="12" cy="12" r="2.5" fill="currentColor"/><path d="M7.5 7.5a6.4 6.4 0 0 0 0 9M16.5 7.5a6.4 6.4 0 0 1 0 9M4.6 4.6a10.5 10.5 0 0 0 0 14.8M19.4 4.6a10.5 10.5 0 0 1 0 14.8"/>',
 mega:'<path d="M3 10v4h3l7 4V6L6 10z"/><path d="M17 9a4 4 0 0 1 0 6"/>',
 shield:'<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/>',
 check:'<path d="M5 12l4.5 4.5L19 7"/>',
 gear:'<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/>',
 plus:'<path d="M12 5v14M5 12h14"/>',
 trophy:'<path d="M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M7 6H4a3 3 0 0 0 3 4M17 6h3a3 3 0 0 1-3 4M12 14v4M8 21h8"/>',
 flag:'<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>',
 block:'<circle cx="12" cy="12" r="9"/><path d="M5.6 5.6l12.8 12.8"/>',
 hangup:'<path d="M3 14c5-5 13-5 18 0l-2.5 2.5-3.5-1.5v-3a12 12 0 0 0-6 0v3L5.5 16.5z"/>',
 search:'<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>',
 clock:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
 users:'<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.7-3.5 3.4-5.5 6.5-5.5s5.8 2 6.5 5.5M16 4.5a3.5 3.5 0 0 1 0 7M18 14.6c2 .8 3.2 2.6 3.5 5.4"/>',
 crown:'<path d="M3 8l4 4 5-7 5 7 4-4-2 11H5z"/>',
 wine:'<path d="M8 3h8l-.5 6a3.5 3.5 0 0 1-7 0z"/><path d="M12 12.5V20M8.5 20h7"/>',
 bookmark:'<path d="M6 3h12v18l-6-4.5L6 21z"/>',
 image:'<rect x="3" y="4" width="18" height="16" rx="3"/><circle cx="9" cy="9.5" r="1.8"/><path d="M21 16l-5-5-9 9"/>',
 poll:'<path d="M5 20V10M12 20V4M19 20v-7"/>',
 edit:'<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>',
 logout:'<path d="M10 4H5v16h5M15 8l4 4-4 4M19 12H9"/>',
 download:'<path d="M12 4v11M7 10.5l5 5 5-5M5 20h14"/>',
 trash:'<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v6M14 11v6"/>',
 lock:'<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
 camera:'<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>',
 story:'<circle cx="12" cy="12" r="9" stroke-dasharray="3 2.6"/><path d="M12 8v8M8 12h8"/>',
 chart:'<path d="M4 4v16h16"/><path d="M8 15l3-4 3 2 5-6"/>',
 share:'<circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="6" r="2.5"/><circle cx="18" cy="18" r="2.5"/><path d="M8.2 10.8l7.6-3.6M8.2 13.2l7.6 3.6"/>'
};
const ic=(n,f)=>`<svg viewBox="0 0 24 24" fill="${f||'none'}" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${IC[n]}</svg>`;

/* generated "photos": Georgian landscapes drawn on canvas */
const artCache={};
function rnd(seed){let s=seed%2147483647;if(s<=0)s+=2147483646;return()=>(s=s*16807%2147483647)/2147483647}
const SKY={mtn:[['#0F2A4A','#F2A65A'],['#1B1035','#E86F7A'],['#4F92CC','#E8F1F7'],['#2B1B3F','#F7B267']],sea:[['#1A2A6C','#FDBB2D'],['#2B5876','#F6A17B'],['#3A1C71','#FFAF7B']],city:[['#07071A','#2D1B4E'],['#0B1026','#3B2559']],vine:[['#F7B267','#F4845F'],['#87B6D6','#E9F2D0'],['#E8A87C','#FCE1B4']]};
function art(kind,seed,w=480,h=480){
 const key=kind+seed+'_'+w+'x'+h;if(artCache[key])return artCache[key];
 const c=document.createElement('canvas');c.width=w;c.height=h;const x=c.getContext('2d');const r=rnd(seed*7919+13);
 const sk=SKY[kind][seed%SKY[kind].length];const g=x.createLinearGradient(0,0,0,h);g.addColorStop(0,sk[0]);g.addColorStop(1,sk[1]);x.fillStyle=g;x.fillRect(0,0,w,h);
 if(kind==='city'){for(let i=0;i<90;i++){x.fillStyle=`rgba(255,255,255,${r()*.7})`;x.fillRect(r()*w,r()*h*.5,1.4,1.4)}}
 x.fillStyle=kind==='city'?'rgba(255,240,210,.92)':'rgba(255,238,205,.88)';x.beginPath();x.arc(w*(.2+r()*.6),h*(.16+r()*.18),Math.min(w,h)*(.05+r()*.04),0,7);x.fill();
 if(kind==='city'){
  for(let L=0;L<2;L++){x.fillStyle=`hsl(255,30%,${L?6:14}%)`;x.beginPath();x.moveTo(0,h);for(let i=0;i<=w;i+=w/8)x.lineTo(i,h*(.45+L*.1)-r()*h*.08);x.lineTo(w,h);x.fill()}
  for(let i=0;i<w;){const bw=w*(.05+r()*.09),bh=h*(.12+r()*.3);x.fillStyle=`hsl(258,28%,${7+r()*7}%)`;x.fillRect(i,h-bh,bw,bh);
   for(let y=h-bh+8;y<h-6;y+=h*.025)for(let xx=i+4;xx<i+bw-5;xx+=w*.02)if(r()<.38){x.fillStyle=`rgba(255,${190+r()*55|0},120,${.45+r()*.55})`;x.fillRect(xx,y,w*.008,h*.012)}
   i+=bw+2}
  return artCache[key]=c.toDataURL('image/jpeg',.85)}
 const n=kind==='sea'?2:kind==='vine'?3:4;
 for(let L=0;L<n;L++){const base=h*(.42+L*.11);
  x.fillStyle=kind==='vine'?`hsl(${95+L*10},38%,${46-L*9}%)`:`hsl(${222+L*8},${28+L*4}%,${Math.max(9,48-L*12)}%)`;
  x.beginPath();x.moveTo(0,h);for(let i=0;i<=w+1;i+=w/14){x.lineTo(i,base-r()*h*(kind==='mtn'?.24:.08)*(L===0?1.3:1))}x.lineTo(w,h);x.fill();
  if(kind==='mtn'&&L===0){x.fillStyle='rgba(255,255,255,.35)';x.fillRect(0,base-h*.32,w,h*.012)}}
 if(kind==='sea'){const sy=h*.6;const sg=x.createLinearGradient(0,sy,0,h);sg.addColorStop(0,'rgba(30,50,110,.92)');sg.addColorStop(1,'rgba(8,16,40,.98)');x.fillStyle=sg;x.fillRect(0,sy,w,h-sy);
  for(let i=0;i<60;i++){x.fillStyle=`rgba(255,215,160,${r()*.55})`;const yy=sy+r()*(h-sy);x.fillRect(w*.5-w*.18*r()+w*.18*r()-w*.06,yy,w*(.04+r()*.12),2)}}
 if(kind==='vine'){for(let row=0;row<7;row++){const y=h*.6+row*h*.06;x.strokeStyle=`hsl(105,42%,${30-row*2}%)`;x.lineWidth=4+row*2.4;x.beginPath();for(let i=0;i<=w;i+=8)x.lineTo(i,y+Math.sin(i/22+row)*3);x.stroke();
  for(let j=0;j<6;j++){x.fillStyle=`hsl(${280+r()*30},48%,${22+r()*10}%)`;x.beginPath();x.arc(r()*w,y+4+row,2.5+row*.8,0,7);x.fill()}}}
 return artCache[key]=c.toDataURL('image/jpeg',.85)}

