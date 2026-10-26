/* signed distance shapes, smooth blends, and a surface-nets mesher: the people are sculpted from these */
'use strict';
const V=(x,y,z)=>[x,y,z];
const sub=(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]],add=(a,b)=>[a[0]+b[0],a[1]+b[1],a[2]+b[2]],mul=(a,k)=>[a[0]*k,a[1]*k,a[2]*k];
const dot=(a,b)=>a[0]*b[0]+a[1]*b[1]+a[2]*b[2],len=a=>Math.hypot(a[0],a[1],a[2]),norm=a=>{const l=len(a)||1;return[a[0]/l,a[1]/l,a[2]/l]};
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const clamp=(v,a,b)=>v<a?a:v>b?b:v,mix=(a,b,t)=>a+(b-a)*t,sstep=(a,b,x)=>{const t=clamp((x-a)/(b-a),0,1);return t*t*(3-2*t)};
/* blends: a smooth union rounds the join over a width k; a smooth subtraction carves with a rounded edge */
function smin(a,b,k){if(k<=0)return Math.min(a,b);const h=Math.max(k-Math.abs(a-b),0)/k;return Math.min(a,b)-h*h*k*.25}
const smax=(a,b,k)=>-smin(-a,-b,k);
/* shapes */
const sphere=(p,c,r)=>Math.hypot(p[0]-c[0],p[1]-c[1],p[2]-c[2])-r;
function ellipsoid(p,c,r){const x=(p[0]-c[0])/r[0],y=(p[1]-c[1])/r[1],z=(p[2]-c[2])/r[2],k0=Math.hypot(x,y,z),k1=Math.hypot(x/r[0],y/r[1],z/r[2]);return k1<1e-9?-Math.min(r[0],r[1],r[2]):k0*(k0-1)/k1}
/* a round cone: from a (radius ra) to b (radius rb) */
function cone(p,a,b,ra,rb){const ba=sub(b,a),pa=sub(p,a),l2=dot(ba,ba),t=clamp(dot(pa,ba)/l2,0,1),q=sub(pa,mul(ba,t));return len(q)-mix(ra,rb,t)}
const capsule=(p,a,b,r)=>cone(p,a,b,r,r);
/* a chain of round cones through points with radii */
function chain(p,P,R){let d=1e9;for(let i=0;i<P.length-1;i++)d=Math.min(d,cone(p,P[i],P[i+1],R[i],R[i+1]));return d}
function rbox(p,c,h,r){const q=[Math.abs(p[0]-c[0])-h[0]+r,Math.abs(p[1]-c[1])-h[1]+r,Math.abs(p[2]-c[2])-h[2]+r];return Math.hypot(Math.max(q[0],0),Math.max(q[1],0),Math.max(q[2],0))+Math.min(Math.max(q[0],q[1],q[2]),0)-r}
/* a ring round axis n through c */
function torus(p,c,n,R,r){const d=sub(p,c),h=dot(d,n),rad=len(sub(d,mul(n,h)));return Math.hypot(rad-R,h)-r}
/* quaternions, for shapes set at an angle */
const qax=(x,y,z,a)=>{const s=Math.sin(a/2);return[x*s,y*s,z*s,Math.cos(a/2)]};
const qmul=(a,b)=>[a[3]*b[0]+a[0]*b[3]+a[1]*b[2]-a[2]*b[1],a[3]*b[1]-a[0]*b[2]+a[1]*b[3]+a[2]*b[0],a[3]*b[2]+a[0]*b[1]-a[1]*b[0]+a[2]*b[3],a[3]*b[3]-a[0]*b[0]-a[1]*b[1]-a[2]*b[2]];
const qinv=q=>[-q[0],-q[1],-q[2],q[3]];
function qrot(q,v){const[x,y,z,w]=q,ix=w*v[0]+y*v[2]-z*v[1],iy=w*v[1]+z*v[0]-x*v[2],iz=w*v[2]+x*v[1]-y*v[0],iw=-x*v[0]-y*v[1]-z*v[2];return[ix*w+iw*-x+iy*-z-iz*-y,iy*w+iw*-y+iz*-x-ix*-z,iz*w+iw*-z+ix*-y-iy*-x]}
function qbasis(f,up){const z=norm(f),x=norm(cross(up,z)),y=cross(z,x),tr=x[0]+y[1]+z[2];let S;
 if(tr>0){S=Math.sqrt(tr+1)*2;return[(y[2]-z[1])/S,(z[0]-x[2])/S,(x[1]-y[0])/S,.25*S]}
 if(x[0]>y[1]&&x[0]>z[2]){S=Math.sqrt(1+x[0]-y[1]-z[2])*2;return[.25*S,(y[0]+x[1])/S,(z[0]+x[2])/S,(y[2]-z[1])/S]}
 if(y[1]>z[2]){S=Math.sqrt(1+y[1]-x[0]-z[2])*2;return[(y[0]+x[1])/S,.25*S,(z[1]+y[2])/S,(z[0]-x[2])/S]}
 S=Math.sqrt(1+z[2]-x[0]-y[1])*2;return[(z[0]+x[2])/S,(z[1]+y[2])/S,.25*S,(x[1]-y[0])/S]}

/* surface nets: one vertex per cell the surface passes through (the mean of where it crosses the cell's edges),
   a quad for every grid edge it crosses. normals come from the field itself, so the shading is smooth */
function mesh(f,bmin,bmax,step){const nx=Math.ceil((bmax[0]-bmin[0])/step)+1,ny=Math.ceil((bmax[1]-bmin[1])/step)+1,nz=Math.ceil((bmax[2]-bmin[2])/step)+1;
 const F=new Float32Array(nx*ny*nz),id=(i,j,k)=>(k*ny+j)*nx+i;
 for(let k=0;k<nz;k++)for(let j=0;j<ny;j++)for(let i=0;i<nx;i++)F[id(i,j,k)]=f([bmin[0]+i*step,bmin[1]+j*step,bmin[2]+k*step]);
 const C=new Int32Array((nx-1)*(ny-1)*(nz-1)).fill(-1),cid=(i,j,k)=>(k*(ny-1)+j)*(nx-1)+i,P=[],N=[],I=[];
 const E=[[0,0,0,1,0,0],[0,1,0,1,1,0],[0,0,1,1,0,1],[0,1,1,1,1,1],[0,0,0,0,1,0],[1,0,0,1,1,0],[0,0,1,0,1,1],[1,0,1,1,1,1],[0,0,0,0,0,1],[1,0,0,1,0,1],[0,1,0,0,1,1],[1,1,0,1,1,1]];
 for(let k=0;k<nz-1;k++)for(let j=0;j<ny-1;j++)for(let i=0;i<nx-1;i++){let neg=0;for(let c=0;c<8;c++)if(F[id(i+(c&1),j+((c>>1)&1),k+(c>>2))]<0)neg++;if(neg===0||neg===8)continue;
  let sx=0,sy=0,sz=0,n=0;for(const e of E){const a=F[id(i+e[0],j+e[1],k+e[2])],b=F[id(i+e[3],j+e[4],k+e[5])];if((a<0)===(b<0))continue;const t=a/(a-b);sx+=e[0]+(e[3]-e[0])*t;sy+=e[1]+(e[4]-e[1])*t;sz+=e[2]+(e[5]-e[2])*t;n++}
  const p=[bmin[0]+(i+sx/n)*step,bmin[1]+(j+sy/n)*step,bmin[2]+(k+sz/n)*step],h=step*.5,g=norm([f([p[0]+h,p[1],p[2]])-f([p[0]-h,p[1],p[2]]),f([p[0],p[1]+h,p[2]])-f([p[0],p[1]-h,p[2]]),f([p[0],p[1],p[2]+h])-f([p[0],p[1],p[2]-h])]);
  C[cid(i,j,k)]=P.length/3;P.push(p[0],p[1],p[2]);N.push(g[0],g[1],g[2])}
 /* quads: an x-edge between (i,j,k) and (i+1,j,k) is shared by the cells (i, j-1..j, k-1..k) */
 const quad=(a,b,c,d,flip)=>{if(a<0||b<0||c<0||d<0)return;if(flip)I.push(a,c,b,a,d,c);else I.push(a,b,c,a,c,d)};
 for(let k=1;k<nz-1;k++)for(let j=1;j<ny-1;j++)for(let i=0;i<nx-1;i++){const a=F[id(i,j,k)],b=F[id(i+1,j,k)];if((a<0)===(b<0))continue;quad(C[cid(i,j-1,k-1)],C[cid(i,j,k-1)],C[cid(i,j,k)],C[cid(i,j-1,k)],a<0)}
 for(let k=1;k<nz-1;k++)for(let j=0;j<ny-1;j++)for(let i=1;i<nx-1;i++){const a=F[id(i,j,k)],b=F[id(i,j+1,k)];if((a<0)===(b<0))continue;quad(C[cid(i-1,j,k-1)],C[cid(i-1,j,k)],C[cid(i,j,k)],C[cid(i,j,k-1)],a<0)}
 for(let k=0;k<nz-1;k++)for(let j=1;j<ny-1;j++)for(let i=1;i<nx-1;i++){const a=F[id(i,j,k)],b=F[id(i,j,k+1)];if((a<0)===(b<0))continue;quad(C[cid(i-1,j-1,k)],C[cid(i,j-1,k)],C[cid(i,j,k)],C[cid(i-1,j,k)],a<0)}
 return{p:P,n:N,i:I}}
module.exports={V,sub,add,mul,dot,len,norm,cross,clamp,mix,sstep,smin,smax,sphere,ellipsoid,cone,capsule,chain,rbox,torus,qax,qmul,qinv,qrot,qbasis,mesh};
