/* fewer triangles with the same shape: edges collapse cheapest-first by the quadric error of the planes they touch
   (Garland and Heckbert). edges on an open rim are kept, and a collapse that would fold a triangle over is refused */
'use strict';
function simplify(P,I,target){const nv=P.length/3,nt=I.length/3;const Qv=new Float64Array(nv*10);
 const tri=new Int32Array(I),alive=new Uint8Array(nt).fill(1),pos=new Float64Array(P),vt=Array.from({length:nv},()=>[]);
 for(let t=0;t<nt;t++)for(let k=0;k<3;k++)vt[tri[t*3+k]].push(t);
 const addQ=(v,a,b,c,d,w)=>{const o=v*10,q=[a*a,a*b,a*c,a*d,b*b,b*c,b*d,c*c,c*d,d*d];for(let k=0;k<10;k++)Qv[o+k]+=q[k]*w};
 const tn=t=>{const a=tri[t*3]*3,b=tri[t*3+1]*3,c=tri[t*3+2]*3,ux=pos[b]-pos[a],uy=pos[b+1]-pos[a+1],uz=pos[b+2]-pos[a+2],vx=pos[c]-pos[a],vy=pos[c+1]-pos[a+1],vz=pos[c+2]-pos[a+2];return[uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx]};
 for(let t=0;t<nt;t++){const n=tn(t),l=Math.hypot(n[0],n[1],n[2]);if(l<1e-12)continue;const a=n[0]/l,b=n[1]/l,c=n[2]/l,v0=tri[t*3]*3,d=-(a*pos[v0]+b*pos[v0+1]+c*pos[v0+2]);for(let k=0;k<3;k++)addQ(tri[t*3+k],a,b,c,d,l*.5)}
 /* the rim: an edge used by one triangle only */
 const ek=(a,b)=>a<b?a*nv+b:b*nv+a,ecount=new Map();for(let t=0;t<nt;t++)for(let k=0;k<3;k++){const e=ek(tri[t*3+k],tri[t*3+(k+1)%3]);ecount.set(e,(ecount.get(e)||0)+1)}
 const rim=new Uint8Array(nv);for(const[e,n]of ecount)if(n===1){rim[Math.floor(e/nv)]=1;rim[e%nv]=1}
 const err=(o,x,y,z)=>Qv[o]*x*x+2*Qv[o+1]*x*y+2*Qv[o+2]*x*z+2*Qv[o+3]*x+Qv[o+4]*y*y+2*Qv[o+5]*y*z+2*Qv[o+6]*y+Qv[o+7]*z*z+2*Qv[o+8]*z+Qv[o+9];
 const S=new Float64Array(10);
 function best(a,b){for(let k=0;k<10;k++)S[k]=Qv[a*10+k]+Qv[b*10+k];const save=Qv.subarray(0,10).slice();for(let k=0;k<10;k++)Qv[k]=S[k];
  const A=a*3,B=b*3,c=[[pos[A],pos[A+1],pos[A+2]],[pos[B],pos[B+1],pos[B+2]],[(pos[A]+pos[B])/2,(pos[A+1]+pos[B+1])/2,(pos[A+2]+pos[B+2])/2]];let bi=0,be=1e30;
  for(let i=0;i<3;i++){if(rim[a]&&i!==0)continue;if(rim[b]&&i!==1&&!rim[a])continue;const e=err(0,c[i][0],c[i][1],c[i][2]);if(e<be){be=e;bi=i}}
  for(let k=0;k<10;k++)Qv[k]=save[k];return[Math.max(0,be),c[bi]]}
 /* a heap of edges, stale entries skipped by a stamp per vertex */
 const H=[],stamp=new Uint32Array(nv);const push=x=>{H.push(x);let i=H.length-1;while(i>0){const p=(i-1)>>1;if(H[p][0]<=H[i][0])break;[H[p],H[i]]=[H[i],H[p]];i=p}};
 const pop=()=>{const top=H[0],last=H.pop();if(H.length){H[0]=last;let i=0;for(;;){const l=i*2+1,r=l+1;let m=i;if(l<H.length&&H[l][0]<H[m][0])m=l;if(r<H.length&&H[r][0]<H[m][0])m=r;if(m===i)break;[H[m],H[i]]=[H[i],H[m]];i=m}}return top};
 const queue=(a,b)=>{if(rim[a]&&rim[b])return;const[e,p]=best(a,b);push([e,a,b,stamp[a],stamp[b],p])};
 for(const e of ecount.keys()){const a=Math.floor(e/nv),b=e%nv;queue(a,b)}
 const parent=new Int32Array(nv).map((_,i)=>i);let live=nt;
 while(live>target&&H.length){const[,a,b,sa,sb,p]=pop();if(stamp[a]!==sa||stamp[b]!==sb||parent[a]!==a||parent[b]!==b)continue;
  /* refuse a collapse that flips a triangle round a or b */
  let ok=true;const old=[pos[a*3],pos[a*3+1],pos[a*3+2]],oldb=[pos[b*3],pos[b*3+1],pos[b*3+2]];
  for(const v of[a,b])for(const t of vt[v]){if(!alive[t])continue;const has=[tri[t*3],tri[t*3+1],tri[t*3+2]];if(has.includes(a)&&has.includes(b))continue;
   const n0=tn(t);const o=v*3,sv=[pos[o],pos[o+1],pos[o+2]];pos[o]=p[0];pos[o+1]=p[1];pos[o+2]=p[2];const n1=tn(t);pos[o]=sv[0];pos[o+1]=sv[1];pos[o+2]=sv[2];
   if(n0[0]*n1[0]+n0[1]*n1[1]+n0[2]*n1[2]<=Math.hypot(...n0)*Math.hypot(...n1)*.2){ok=false;break}}
  if(!ok)continue;
  pos[a*3]=p[0];pos[a*3+1]=p[1];pos[a*3+2]=p[2];for(let k=0;k<10;k++)Qv[a*10+k]+=Qv[b*10+k];parent[b]=a;rim[a]=rim[a]|rim[b];
  for(const t of vt[b]){if(!alive[t])continue;for(let k=0;k<3;k++)if(tri[t*3+k]===b)tri[t*3+k]=a;const x=tri[t*3],y=tri[t*3+1],z=tri[t*3+2];if(x===y||y===z||x===z){alive[t]=0;live--}else vt[a].push(t)}
  vt[b]=[];vt[a]=vt[a].filter(t=>alive[t]);stamp[a]++;stamp[b]++;
  const nb=new Set();for(const t of vt[a])for(let k=0;k<3;k++){const v=tri[t*3+k];if(v!==a)nb.add(v)}for(const v of nb)queue(a,v)}
 /* compact: only the vertices still used */
 const map=new Int32Array(nv).fill(-1),OP=[],OI=[];for(let t=0;t<nt;t++){if(!alive[t])continue;for(let k=0;k<3;k++){const v=tri[t*3+k];if(map[v]<0){map[v]=OP.length/3;OP.push(pos[v*3],pos[v*3+1],pos[v*3+2])}OI.push(map[v])}}
 return{p:OP,i:OI}}
module.exports={simplify};
