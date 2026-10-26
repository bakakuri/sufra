/* the people at the table, sculpted as smooth shapes. coordinates are those of the game's person:
   the body in the seat's frame (the chair back behind at z -1.8, the table in front), the head about its neck pivot,
   each forearm about its elbow. the head is built round its centre HC above the pivot */
'use strict';
const S=require('./sdf.js');const{V,sub,add,mul,norm,clamp,mix,sstep,smin,smax,sphere,ellipsoid,cone,capsule,chain,rbox,torus,qax,qmul,qinv,qrot,qbasis}=S;
const HC=[0,.84,.08];
const EYE={m:{x:.35,y:.02,z:.72,r:.24,lid:.74},f:{x:.345,y:.03,z:.715,r:.255,lid:.8}};
/* heads a little bigger than the bodies, as in animated films: shapes are made at this scale round HC */
const HS=1.1,scaled=f=>P=>f(mul(sub(P,HC),1/HS))*HS;
const EYEX={};for(const k in EYE){const e=EYE[k];EYEX[k]={x:e.x*HS,y:e.y*HS,z:e.z*HS,r:e.r*HS,lid:e.lid}}
const mir=p=>[Math.abs(p[0]),p[1],p[2]];
/* the head: one round mass for skull and face, the muzzle carried forward, round cheeks, a chin;
   a big friendly nose, lids over the eyes, lips and ears */
function headF(fem){const E=fem?EYE.f:EYE.m;return scaled(p=>{const q=mir(p);
 let d=ellipsoid(p,[0,.1,-.05],fem?[.9,1.0,.96]:[.92,1.02,.97]);
 d=smin(d,ellipsoid(p,[0,-.42,.2],fem?[.6,.52,.64]:[.64,.55,.66]),.36);
 d=smin(d,sphere(q,[fem?.4:.41,-.2,.5],fem?.34:.32),.26);
 d=smin(d,fem?sphere(p,[0,-.85,.42],.22):sphere(q,[.09,-.88,.42],.23),.25);
 if(!fem)d=smin(d,sphere(q,[.48,-.62,.12],.3),.3);
 /* the brow, a soft ridge over each eye */
 d=smin(d,capsule(q,[.1,.27,.79],[.5,.3,.62],fem?.09:.115),.14);
 /* the nose: a bridge, a round tip, the wings, the nostrils pressed in */
 if(fem){d=smin(d,chain(p,[[0,.1,.86],[0,-.12,1.0],[0,-.21,1.05]],[.07,.08,.09]),.09);d=smin(d,sphere(p,[0,-.23,1.07],.115),.07);d=smin(d,sphere(q,[.085,-.27,.99],.07),.045);d=smax(d,-sphere(q,[.05,-.32,1.02],.024),.014)}
 else{d=smin(d,chain(p,[[0,.12,.86],[0,-.12,1.03],[0,-.25,1.11]],[.09,.1,.12]),.1);d=smin(d,sphere(p,[0,-.27,1.13],.16),.08);d=smin(d,sphere(q,[.12,-.31,1.02],.09),.05);d=smax(d,-sphere(q,[.065,-.38,1.07],.03),.018)}
 /* lips and the line of the mouth, with small dents at its corners */
 const lz=fem?.87:.86;d=smin(d,ellipsoid(p,[0,-.6,lz-.04],fem?[.12,.05,.05]:[.12,.04,.045]),.06);
 d=smax(d,-chain(p,[[-.17,-.545,lz-.02],[0,-.565,lz+.035],[.17,-.545,lz-.02]],[.008,.011,.008]),.01);
 /* the ears, with a hollow */
 d=smin(d,ellipsoid(q,[.88,-.05,-.05],fem?[.095,.24,.17]:[.105,.27,.19]),.06);d=smax(d,-ellipsoid(q,[.95,-.05,-.02],[.05,.16,.1]),.03);
 /* the neck stub that disappears into the collar */
 d=smin(d,cone(p,[0,-.7,-.15],[0,-1.75,-.2],.4,.38),.25);
 /* the eye: a socket for the eyeball, an upper lid over its top, a thin lower lid */
 const c=[E.x,E.y,E.z];const rel=sub(q,c);d=smax(d,-sphere(q,c,E.r+.01),.04);
 const nU=norm([0,1,-.18]),up=rel[0]*nU[0]+rel[1]*nU[1]+rel[2]*nU[2];d=smin(d,smax(sphere(q,c,E.r+.024),-(up-E.lid*E.r),.015),.025);
 const nD=norm([0,-1,.25]),dn=rel[0]*nD[0]+rel[1]*nD[1]+rel[2]*nD[2];d=smin(d,smax(sphere(q,c,E.r+.02),-(dn-.74*E.r),.02),.025);
 return d})}
/* hair, sculpted in locks; each style keeps clear of the face and the ears */
const keepAbove=(d,p,h,k)=>smax(d,-(p[1]-h),k);
const earClear=(d,q)=>smax(d,-ellipsoid(q,[.95,-.06,-.05],[.2,.36,.3]),.06);
function hairF(style){return scaled(p=>{const q=mir(p);let d;
 if(style==='short'){d=ellipsoid(p,[0,.2,-.07],[.96,1.1,1.04]);
  let h=mix(-.55,.5,sstep(-.45,.45,p[2]))+.18*sstep(.28,.64,q[0])*sstep(0,.5,p[2]);h=Math.max(h,.24*sstep(.66,.8,q[0])*sstep(-.45,-.15,p[2]));d=keepAbove(d,p,h,.08);
  /* the volume above the forehead, swept up and over to the right */
  d=smin(d,ellipsoid(qrot(qax(0,0,1,.12),sub(p,[-.05,.98,.42])),[0,0,0],[.78,.38,.52]),.28);
  d=smin(d,ellipsoid(qrot(qax(0,0,1,-.3),sub(p,[.25,.86,.66])),[0,0,0],[.5,.22,.28]),.16);
  for(let i=0;i<8;i++){const x0=-.62+i*.18;d=smin(d,capsule(p,[x0,.95-Math.abs(x0)*.25,.66],[x0*1.05+.18,1.18-Math.abs(x0)*.22,-.55],.12),.07)}
  d=smin(d,capsule(q,[.86,.32,.18],[.88,-.05,.22],.065),.05);d=smax(d,-capsule(p,[-.38,1.2,.62],[-.44,1.12,-.5],.03),.025)}
 else if(style==='curly'){d=ellipsoid(p,[0,.3,-.1],[1.0,1.1,1.08]);let h=mix(-.55,.6,sstep(-.6,.5,p[2]));h+=.2*sstep(.6,.9,q[0])*sstep(-.1,.6,p[2]);d=keepAbove(d,p,h,.08);
  let R=17;const rnd=()=>{R=(R*16807)%2147483647;return R/2147483647};
  for(let k=0;k<90;k++){const th=rnd()*Math.PI*2,ph=Math.acos(1-2*rnd()*.8),s=[Math.sin(ph)*Math.sin(th),Math.cos(ph),Math.sin(ph)*Math.cos(th)],c=[s[0]*1.0,.3+s[1]*1.1,-.1+s[2]*1.08],hh=mix(-.55,.6,sstep(-.6,.5,c[2]));if(c[1]<hh+.05)continue;d=smin(d,sphere(p,c,.17+rnd()*.06),.07)}}
 else if(style==='long'){d=ellipsoid(p,[0,.22,-.08],[1.0,1.06,1.07]);d=keepAbove(d,p,mix(-1.7,.44,sstep(-.2,.62,p[2]))+.1*sstep(.3,.7,q[0])*sstep(0,.6,p[2]),.08);
  d=smin(d,rbox(p,[0,-.6,-.42],[.95,1.15,.45],.42),.35);d=smin(d,rbox(q,[.8,-.75,.02],[.2,.85,.36],.18),.3);
  d=smin(d,ellipsoid(qrot(qax(0,0,1,.3),sub(p,[-.22,.62,.66])),[0,0,0],[.6,.2,.26]),.16);d=smin(d,ellipsoid(p,[.3,.7,.6],[.4,.22,.28]),.15);
  for(let i=0;i<7;i++){const x0=-.72+i*.24;d=smin(d,cone(p,[x0*.92,.98-.85*x0*x0,-.38],[x0*1.15,-1.5,-.55],.14,.12),.08)}
  d=smax(d,-ellipsoid(p,[0,-.3,.96],[.66,.9,.46]),.1);d=smax(d,-(p[1]+1.65),.1)}
 else if(style==='pony'){d=ellipsoid(p,[0,.24,-.1],[.965,1.07,1.05]);let h=mix(-.6,.62,sstep(-.6,.5,p[2]))+.08*sstep(.3,.7,q[0])*sstep(0,.5,p[2]);h=Math.max(h,.24*sstep(.66,.8,q[0])*sstep(-.45,-.15,p[2]));d=keepAbove(d,p,h,.07);
  for(let i=0;i<9;i++){const x0=-.72+i*.18;d=smin(d,capsule(p,[x0,.98-Math.abs(x0)*.42,.6],[x0*.35,.78,-.98],.1),.06)}
  d=smin(d,ellipsoid(qrot(qax(0,0,1,-.35),sub(p,[.2,.86,.6])),[0,0,0],[.38,.16,.2]),.12);
  d=smin(d,chain(p,[[0,.66,-1.0],[0,.16,-1.28],[0,-.7,-1.3]],[.28,.25,.13]),.15);d=smin(d,torus(p,[0,.64,-1.03],norm([0,.3,-1]),.21,.07),.03)}
 else{/* bald: a band round the back and the sides */d=ellipsoid(p,[0,.12,-.12],[.99,1.0,1.06]);d=smax(d,p[1]-.34,.08);d=smax(d,-.58-p[1],.08);d=smax(d,p[2]-.22,.12)}
 return earClear(d,q)})}
/* a big soft moustache, and a short beard round the jaw */
function musF(){return scaled(p=>{const q=mir(p);let d=ellipsoid(qrot(qax(0,0,1,-.36),sub(q,[.19,-.45,1.02])),[0,0,0],[.25,.1,.12]);d=smin(d,ellipsoid(p,[0,-.42,1.06],[.1,.08,.08]),.06);return d})}
function beardF(){return scaled(p=>{let d=ellipsoid(p,[0,-.5,.18],[.9,.74,.92]);d=smax(d,p[1]+.18,.1);d=smax(d,-(p[2]+.28),.1);d=smax(d,-ellipsoid(p,[0,-.58,1.0],[.22,.12,.26]),.05);return earClear(d,mir(p))})}
/* the body in a ribbed sweater: chest, belly, round shoulders and upper arms, a collar */
const ELB=s=>[s*2.3,.55,1.0];
function bodyF(fem){return p=>{const q=mir(p);
 let d=smin(ellipsoid(p,[0,1.2,0],fem?[1.42,1.6,.96]:[1.55,1.65,1.0]),ellipsoid(p,[0,-.9,.05],fem?[1.32,1.65,.95]:[1.45,1.7,.98]),.7);
 d=smin(d,sphere(q,[fem?1.36:1.48,2.0,-.05],fem?.56:.62),.55);d=smin(d,cone(q,[fem?1.3:1.4,2.1,-.1],[0,2.55,-.05],.45,.42),.3);
 if(fem)d=smin(d,sphere(q,[.46,1.28,.6],.38),.5);
 for(const s of[-1,1])d=smin(d,cone(p,[s*(fem?1.6:1.72),2.0,0],ELB(s),fem?.48:.52,fem?.41:.44),.25);
 d=smin(d,torus(p,[0,2.72,.08],norm([0,1,.14]),fem?.46:.49,.16),.05);
 return smax(d,-(p[1]+2.8),.05)}}
const neckF=()=>p=>cone(p,[0,2.35,-.02],[0,3.45,.12],.43,.39);
/* a forearm in its sleeve with a ribbed cuff, about the elbow; and the hand at its wrist */
function armW(s){const E=ELB(s),W=[s*.98,1.12,2.38],fa=norm(sub(W,E));return{E,W,fa,cuff:sub(add(W,mul(fa,-.14)),E),hand:sub(add(W,mul(fa,.1)),E),hq:qbasis([-s*.7,-.06,1],[s*.3,1,0])}}
function sleeveF(s){const A=armW(s);return p=>{let d=cone(p,[0,0,0],sub(A.cuff,mul(A.fa,.02)),.47,.37);d=smin(d,torus(p,A.cuff,A.fa,.36,.1),.04);return d}}
/* the hand: palm down, fingers forward and curled, the thumb on the inside */
function handF(s){const A=armW(s),iq=qinv(A.hq),th=-s;return P=>{const p=qrot(iq,sub(P,A.hand));
 let d=rbox(p,[0,0,.27],[.22,.085,.22],.075);const lens=[.3,.34,.31,.24];
 [-.165,-.055,.055,.165].forEach((x,i)=>{const L=lens[th>0?3-i:i];d=smin(d,chain(p,[[x,-.005,.45],[x,-.05,.45+L*.55],[x,-.13,.45+L]],[.066,.06,.054]),.03)});
 d=smin(d,chain(p,[[th*.17,-.02,.12],[th*.34,-.06,.33],[th*.4,-.1,.47]],[.08,.072,.064]),.04);return d}}
module.exports={HC,EYE:EYEX,HS,headF,hairF,musF,beardF,bodyF,neckF,sleeveF,handF,armW,ELB};
