/* 3D boards for the games: a small WebGL renderer. soft shadows from one warm lamp, lacquered wood and ivory,
   pieces that glide and hop, dice that tumble, cards that fly. one canvas serves every game and moves into
   whichever board is on screen; each game keeps its own scene. a tap calls the same actions as the flat board,
   so the rules live in one place. loaded only when a game opens */
const G3D={ok:null,gl:null,cv:null,sc:null,raf:0,asp:1,sm:null,hp:true,bound:null,P:null,Q:null,white:null,ro:null,slow:0};

/* ---------- math: vectors, quaternions [x,y,z,w], column-major 4x4 matrices ---------- */
const v3={add:(a,b)=>[a[0]+b[0],a[1]+b[1],a[2]+b[2]],sub:(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]],mul:(a,s)=>[a[0]*s,a[1]*s,a[2]*s],
 dot:(a,b)=>a[0]*b[0]+a[1]*b[1]+a[2]*b[2],cross:(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]],
 len:a=>Math.hypot(a[0],a[1],a[2]),norm:a=>{const l=Math.hypot(a[0],a[1],a[2])||1;return[a[0]/l,a[1]/l,a[2]/l]},lerp:(a,b,t)=>[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t]};
const qt={id:()=>[0,0,0,1],
 ax:(x,y,z,a)=>{const s=Math.sin(a/2),l=Math.hypot(x,y,z)||1;return[x/l*s,y/l*s,z/l*s,Math.cos(a/2)]},
 mul:(a,b)=>[a[3]*b[0]+a[0]*b[3]+a[1]*b[2]-a[2]*b[1],a[3]*b[1]-a[0]*b[2]+a[1]*b[3]+a[2]*b[0],a[3]*b[2]+a[0]*b[1]-a[1]*b[0]+a[2]*b[3],a[3]*b[3]-a[0]*b[0]-a[1]*b[1]-a[2]*b[2]],
 slerp(a,b,t){let d=a[0]*b[0]+a[1]*b[1]+a[2]*b[2]+a[3]*b[3],c=b;if(d<0){d=-d;c=b.map(x=>-x)}
  if(d>.9995){const r=a.map((x,i)=>x+(c[i]-x)*t),l=Math.hypot(r[0],r[1],r[2],r[3]);return r.map(x=>x/l)}
  const th=Math.acos(d),s=Math.sin(th),wa=Math.sin((1-t)*th)/s,wb=Math.sin(t*th)/s;return a.map((x,i)=>x*wa+c[i]*wb)},
 /* yaw about y, then tilt about x, then spin about z: Ry*Rx*Rz (the spin is applied first) */
 e:(x,y,z)=>qt.mul(qt.mul(qt.ax(0,1,0,y),qt.ax(1,0,0,x)),qt.ax(0,0,1,z)),
 rot(q,v){const[x,y,z,w]=q,t=[2*(y*v[2]-z*v[1]),2*(z*v[0]-x*v[2]),2*(x*v[1]-y*v[0])];return[v[0]+w*t[0]+y*t[2]-z*t[1],v[1]+w*t[1]+z*t[0]-x*t[2],v[2]+w*t[2]+x*t[1]-y*t[0]]},
 inv:q=>[-q[0],-q[1],-q[2],q[3]],
 same:(a,b)=>Math.abs(a[0]*b[0]+a[1]*b[1]+a[2]*b[2]+a[3]*b[3])>.99999};
const m4={
 id(){const m=new Float32Array(16);m[0]=m[5]=m[10]=m[15]=1;return m},
 mul(a,b){const o=new Float32Array(16);for(let c=0;c<4;c++)for(let r=0;r<4;r++){let s=0;for(let k=0;k<4;k++)s+=a[k*4+r]*b[c*4+k];o[c*4+r]=s}return o},
 persp(f,asp,n,fa){const t=1/Math.tan(f/2),o=new Float32Array(16);o[0]=t/asp;o[5]=t;o[10]=(fa+n)/(n-fa);o[11]=-1;o[14]=2*fa*n/(n-fa);return o},
 ortho(l,r,b,t,n,f){const o=m4.id();o[0]=2/(r-l);o[5]=2/(t-b);o[10]=-2/(f-n);o[12]=-(r+l)/(r-l);o[13]=-(t+b)/(t-b);o[14]=-(f+n)/(f-n);return o},
 look(e,c,up){const z=v3.norm(v3.sub(e,c)),x=v3.norm(v3.cross(up,z)),y=v3.cross(z,x),o=new Float32Array(16);
  o[0]=x[0];o[4]=x[1];o[8]=x[2];o[1]=y[0];o[5]=y[1];o[9]=y[2];o[2]=z[0];o[6]=z[1];o[10]=z[2];o[12]=-v3.dot(x,e);o[13]=-v3.dot(y,e);o[14]=-v3.dot(z,e);o[15]=1;return o},
 trs(p,q,s){const[x,y,z,w]=q,sx=s.length?s[0]:s,sy=s.length?s[1]:s,sz=s.length?s[2]:s,x2=x+x,y2=y+y,z2=z+z,xx=x*x2,xy=x*y2,xz=x*z2,yy=y*y2,yz=y*z2,zz=z*z2,wx=w*x2,wy=w*y2,wz=w*z2,m=new Float32Array(16);
  m[0]=(1-(yy+zz))*sx;m[1]=(xy+wz)*sx;m[2]=(xz-wy)*sx;m[4]=(xy-wz)*sy;m[5]=(1-(xx+zz))*sy;m[6]=(yz+wx)*sy;m[8]=(xz+wy)*sz;m[9]=(yz-wx)*sz;m[10]=(1-(xx+yy))*sz;m[12]=p[0];m[13]=p[1];m[14]=p[2];m[15]=1;return m},
 xf(m,p){const w=m[3]*p[0]+m[7]*p[1]+m[11]*p[2]+m[15];return[(m[0]*p[0]+m[4]*p[1]+m[8]*p[2]+m[12])/w,(m[1]*p[0]+m[5]*p[1]+m[9]*p[2]+m[13])/w,(m[2]*p[0]+m[6]*p[1]+m[10]*p[2]+m[14])/w,w]}};
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const ease=k=>k<.5?4*k*k*k:1-Math.pow(-2*k+2,3)/2,easeOut=k=>1-Math.pow(1-k,3);
const sLerp=(a,b,e)=>a.length||b.length?[0,1,2].map(k=>(a.length?a[k]:a)+((b.length?b[k]:b)-(a.length?a[k]:a))*e):a+(b-a)*e;
const sDiff=(a,b)=>a.length||b.length?Math.max(...[0,1,2].map(k=>Math.abs((a.length?a[k]:a)-(b.length?b[k]:b)))):Math.abs(a-b);
const lin=h=>{const n=parseInt(h.slice(1),16);return[(n>>16&255)/255,(n>>8&255)/255,(n&255)/255].map(c=>Math.pow(c,2.2))};

/* ---------- shaders ---------- */
const VS_MAIN=`attribute vec3 aP;attribute vec3 aN;attribute vec2 aU;uniform mat4 uM,uVP,uL;uniform vec4 uUV;varying vec3 vW;varying vec3 vN;varying vec2 vU;varying vec4 vS;
void main(){vec4 w=uM*vec4(aP,1.0);vW=w.xyz;vN=(uM*vec4(aN,0.0)).xyz;vU=uUV.xy+aU*uUV.zw;vS=uL*w;gl_Position=uVP*w;}`;
const FS_MAIN=`uniform sampler2D uT,uSh;uniform vec3 uC,uE,uEye,uLd,uLc,uSky,uGnd,uRe;uniform vec4 uMat,uFx,uSp,uRf,uRc;uniform float uSS,uExp;
varying vec3 vW;varying vec3 vN;varying vec2 vU;varying vec4 vS;
float unp(vec4 c){return dot(c,vec4(1.0,1.0/255.0,1.0/65025.0,1.0/16581375.0));}
float cmp(vec2 uv,float z){return step(z,unp(texture2D(uSh,uv)));}
float pcf(vec2 uv,float z){vec2 t=uv/uSS-0.5;vec2 f=fract(t);vec2 b=(floor(t)+0.5)*uSS;
 return mix(mix(cmp(b,z),cmp(b+vec2(uSS,0.0),z),f.x),mix(cmp(b+vec2(0.0,uSS),z),cmp(b+vec2(uSS,uSS),z),f.x),f.y);}
float shade(float nl){if(uFx.w<0.5)return 1.0;vec3 p=vS.xyz/vS.w*0.5+0.5;if(p.x<0.0||p.x>1.0||p.y<0.0||p.y>1.0||p.z>1.0)return 1.0;
 float z=p.z-0.0007-0.0022*(1.0-nl);float k=uSS*1.5;return (pcf(p.xy+vec2(-k,-k),z)+pcf(p.xy+vec2(k,-k),z)+pcf(p.xy+vec2(-k,k),z)+pcf(p.xy+vec2(k,k),z))*0.25;}
vec3 aces(vec3 x){return clamp((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14),0.0,1.0);}
void main(){float ra=1.0;if(uRf.x>0.0){vec3 d=vW-uRe;vec3 s=uRe+d*((uRf.y-uRe.y)/d.y);if(s.x<uRc.x||s.x>uRc.z||s.z<uRc.y||s.z>uRc.w)discard;ra=uRf.x*(1.0-smoothstep(0.0,uRf.z,uRf.y-vW.y));}
 vec4 tx=uFx.x>0.5?texture2D(uT,vU):vec4(1.0);if(uFx.z>0.5&&tx.a<0.5)discard;
 vec3 base=uC*pow(tx.rgb,vec3(2.2));
 if(uFx.y>0.5){gl_FragColor=vec4(pow(base+uE,vec3(1.0/2.2)),tx.a*uMat.w);return;}
 vec3 n=normalize(vN);if(!gl_FrontFacing)n=-n;vec3 v=normalize(uEye-vW);float nl=max(dot(n,uLd),0.0);float sh=shade(nl);
 float sp=uSp.w>0.0?mix(1.0,1.0-smoothstep(uSp.z*0.45,uSp.z*1.3,length(vW.xz-uSp.xy)),uSp.w):1.0;
 vec3 h=normalize(uLd+v);float spec=pow(max(dot(n,h),0.0),uMat.x)*uMat.y*(uMat.x+8.0)*0.03;
 vec3 amb=mix(uGnd,uSky,n.y*0.5+0.5);float fr=pow(1.0-max(dot(n,v),0.0),5.0);vec3 r=reflect(-v,n);
 vec3 env=mix(uGnd*0.6,uSky*1.5,smoothstep(-0.25,0.85,r.y))+vec3(2.6)*pow(max(dot(r,normalize(vec3(-0.35,0.8,0.5))),0.0),40.0);
 float g=uMat.z*(0.04+0.96*fr);
 vec3 col=base*(amb*(0.5+0.5*sp)+uLc*nl*sh*sp)*(1.0-g*0.6)+uLc*spec*sh*sp+env*g*(0.35+0.65*sp)+uE;
 gl_FragColor=vec4(pow(aces(col*uExp),vec3(1.0/2.2)),uMat.w*tx.a*ra);}`;
const VS_SH=`attribute vec3 aP;uniform mat4 uM,uL;varying float vZ;void main(){vec4 p=uL*(uM*vec4(aP,1.0));vZ=p.z*0.5+0.5;gl_Position=p;}`;
const FS_SH=`varying float vZ;void main(){vec4 e=fract(vZ*vec4(1.0,255.0,65025.0,16581375.0));e-=e.yzww*vec4(1.0/255.0,1.0/255.0,1.0/255.0,0.0);gl_FragColor=e;}`;

function g3Prog(vs,fs,us){const gl=G3D.gl,sh=(t,s)=>{const o=gl.createShader(t);gl.shaderSource(o,s);gl.compileShader(o);if(!gl.getShaderParameter(o,gl.COMPILE_STATUS))throw new Error(gl.getShaderInfoLog(o));return o};
 const p=gl.createProgram();gl.attachShader(p,sh(gl.VERTEX_SHADER,vs));gl.attachShader(p,sh(gl.FRAGMENT_SHADER,fs));['aP','aN','aU'].forEach((n,i)=>gl.bindAttribLocation(p,i,n));gl.linkProgram(p);
 if(!gl.getProgramParameter(p,gl.LINK_STATUS))throw new Error(gl.getProgramInfoLog(p));const u={};for(const n of us)u[n]=gl.getUniformLocation(p,n);return{p,u}}
function g3ShadowFB(){const gl=G3D.gl,S=Math.min(2048,gl.getParameter(gl.MAX_TEXTURE_SIZE)),t=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,t);
 gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,S,S,0,gl.RGBA,gl.UNSIGNED_BYTE,null);for(const k of[gl.TEXTURE_MIN_FILTER,gl.TEXTURE_MAG_FILTER])gl.texParameteri(gl.TEXTURE_2D,k,gl.NEAREST);
 for(const k of[gl.TEXTURE_WRAP_S,gl.TEXTURE_WRAP_T])gl.texParameteri(gl.TEXTURE_2D,k,gl.CLAMP_TO_EDGE);
 const fb=gl.createFramebuffer(),rb=gl.createRenderbuffer();gl.bindRenderbuffer(gl.RENDERBUFFER,rb);gl.renderbufferStorage(gl.RENDERBUFFER,gl.DEPTH_COMPONENT16,S,S);
 gl.bindFramebuffer(gl.FRAMEBUFFER,fb);gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,t,0);gl.framebufferRenderbuffer(gl.FRAMEBUFFER,gl.DEPTH_ATTACHMENT,gl.RENDERBUFFER,rb);
 const ok=gl.checkFramebufferStatus(gl.FRAMEBUFFER)===gl.FRAMEBUFFER_COMPLETE;gl.bindFramebuffer(gl.FRAMEBUFFER,null);if(ok)G3D.sm={fb,t,S}}

function g3Init(){if(G3D.ok!==null)return G3D.ok;G3D.ok=false;
 try{const cv=document.createElement('canvas');cv.className='g3cv';cv.setAttribute('aria-hidden','true');
  const gl=cv.getContext('webgl',{antialias:true,alpha:false,depth:true,stencil:false,powerPreference:'high-performance'})||cv.getContext('experimental-webgl',{antialias:true,alpha:false});if(!gl)return false;
  G3D.cv=cv;G3D.gl=gl;const hp=gl.getShaderPrecisionFormat(gl.FRAGMENT_SHADER,gl.HIGH_FLOAT);G3D.hp=!!hp&&hp.precision>0;
  G3D.af=gl.getExtension('EXT_texture_filter_anisotropic')||gl.getExtension('WEBKIT_EXT_texture_filter_anisotropic');if(G3D.af)G3D.afM=gl.getParameter(G3D.af.MAX_TEXTURE_MAX_ANISOTROPY_EXT);
  G3D.u32=!!gl.getExtension('OES_element_index_uint');
  G3D.P=g3Prog(VS_MAIN,(G3D.hp?'precision highp float;':'precision mediump float;')+FS_MAIN,['uM','uVP','uL','uUV','uT','uSh','uC','uE','uEye','uLd','uLc','uSky','uGnd','uMat','uFx','uSp','uSS','uExp','uRf','uRc','uRe']);
  if(G3D.hp){G3D.Q=g3Prog(VS_SH,'precision highp float;'+FS_SH,['uM','uL']);g3ShadowFB()}
  const w=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,w);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,1,1,0,gl.RGBA,gl.UNSIGNED_BYTE,new Uint8Array([255,255,255,255]));G3D.white=w;
  g3Input(cv);
  cv.addEventListener('webglcontextlost',e=>{e.preventDefault();G3D.ok=false;G3W.fail=true;G3W.ready=false;setTimeout(g3Redraw,0)});
  G3D.ok=true}catch(e){G3D.ok=false;try{console.warn('3D',e)}catch(x){}}
 return G3D.ok}

/* ---------- geometry ---------- */
const geo=()=>({p:[],n:[],u:[],i:[]});
function gv(g,x,y,z,nx,ny,nz,u,v){g.p.push(x,y,z);g.n.push(nx,ny,nz);g.u.push(u,v);return g.p.length/3-1}
function gMerge(...gs){const o=geo();for(const g of gs){const b=o.p.length/3;for(let k=0;k<g.p.length;k++)o.p.push(g.p[k]);for(let k=0;k<g.n.length;k++)o.n.push(g.n[k]);for(let k=0;k<g.u.length;k++)o.u.push(g.u[k]);for(let k=0;k<g.i.length;k++)o.i.push(g.i[k]+b)}return o}
/* move a piece of geometry: position, rotation (quaternion), uniform scale */
function gXf(g,p,q,s=1){for(let k=0;k<g.p.length;k+=3){const v=qt.rot(q,[g.p[k]*s,g.p[k+1]*s,g.p[k+2]*s]),n=qt.rot(q,[g.n[k],g.n[k+1],g.n[k+2]]);g.p[k]=v[0]+p[0];g.p[k+1]=v[1]+p[1];g.p[k+2]=v[2]+p[2];g.n[k]=n[0];g.n[k+1]=n[1];g.n[k+2]=n[2]}return g}
/* a box with rounded edges. faces: 0 top +y, 1 bottom, 2 front +z, 3 back, 4 right +x, 5 left. uv (0,0) is the top-left of each face as you look at it */
const BOXF=[[1,1,0,1,2,1],[1,-1,0,1,2,-1],[2,1,0,1,1,-1],[2,-1,0,-1,1,-1],[0,1,2,-1,1,-1],[0,-1,2,1,1,-1]];
function gBox(w,h,d,r,sg=4,uvf=null,faces=[0,1,2,3,4,5]){const g=geo(),H=[w/2,h/2,d/2];r=Math.max(0,Math.min(r,...H.map(x=>x*.999)));
 const ax=k=>{const a=H[k];if(r<=0)return[-a,a];const pts=[];for(let i=0;i<=sg;i++)pts.push(-a+r*i/sg);for(let i=0;i<=sg;i++)pts.push(a-r+r*i/sg);return pts.filter((v,i,A)=>i===0||Math.abs(v-A[i-1])>1e-7)};
 for(const fi of faces){const[na,ns,ua,us,va,vs]=BOXF[fi],U=ax(ua),V=ax(va),b=g.p.length/3,nu=U.length,nv=V.length;
  const uvec=[0,0,0],vvec=[0,0,0],nvec=[0,0,0];uvec[ua]=us;vvec[va]=vs;nvec[na]=ns;const flip=v3.dot(v3.cross(uvec,vvec),nvec)<0;
  for(let j=0;j<nv;j++)for(let i=0;i<nu;i++){const p=[0,0,0];p[na]=ns*H[na];p[ua]=us*U[i];p[va]=vs*V[j];
   const q=p.map((x,k)=>clamp(x,-(H[k]-r),H[k]-r));let n=v3.sub(p,q),l=v3.len(n);if(l<1e-9){n=nvec;l=1}else n=v3.mul(n,1/l);const pos=r>0?v3.add(q,v3.mul(n,r)):p;
   let u=(U[i]+H[ua])/(2*H[ua]),v=(V[j]+H[va])/(2*H[va]);if(uvf)[u,v]=uvf(fi,u,v);gv(g,pos[0],pos[1],pos[2],n[0],n[1],n[2],u,v)}
  for(let j=0;j<nv-1;j++)for(let i=0;i<nu-1;i++){const a=b+j*nu+i,bb=a+1,c=a+nu+1,dd=a+nu;if(flip)g.i.push(a,c,bb,a,dd,c);else g.i.push(a,bb,c,a,c,dd)}}
 return g}
/* a turned shape from an outline [[radius,height],...] going from the bottom centre to the top centre; sharp turns keep a crisp edge */
function gLathe(prof,sg=40,crease=.82){const g=geo(),n=prof.length,len=[0];for(let i=1;i<n;i++)len.push(len[i-1]+Math.hypot(prof[i][0]-prof[i-1][0],prof[i][1]-prof[i-1][1]));const L=len[n-1]||1;
 const sn=[];for(let i=0;i<n-1;i++){const dr=prof[i+1][0]-prof[i][0],dy=prof[i+1][1]-prof[i][1],l=Math.hypot(dr,dy)||1;sn.push([dy/l,-dr/l])}
 const rows=[];for(let i=0;i<n;i++){const a=sn[i-1],b=sn[i];if(a&&b&&a[0]*b[0]+a[1]*b[1]<crease){rows.push({i,nr:a});rows.push({i,nr:b})}else{const m=a&&b?[a[0]+b[0],a[1]+b[1]]:(a||b),l=Math.hypot(m[0],m[1])||1;rows.push({i,nr:[m[0]/l,m[1]/l]})}}
 rows.forEach(rw=>{rw.b=g.p.length/3;const[r,y]=prof[rw.i];for(let j=0;j<=sg;j++){const a=j/sg*Math.PI*2,c=Math.cos(a),s=Math.sin(a);gv(g,r*c,y,r*s,rw.nr[0]*c,rw.nr[1],rw.nr[0]*s,j/sg,1-len[rw.i]/L)}});
 for(let k=0;k<rows.length-1;k++){if(rows[k].i===rows[k+1].i)continue;const A=rows[k].b,B=rows[k+1].b;for(let j=0;j<sg;j++)g.i.push(A+j,B+j,B+j+1,A+j,B+j+1,A+j+1)}
 return g}
/* a flat outline [[x,y],...] given a thickness along z, with a small chamfer */
function gExtrude(pts,depth,bev){let P=pts.slice();let ar=0;for(let i=0;i<P.length;i++){const a=P[i],b=P[(i+1)%P.length];ar+=a[0]*b[1]-b[0]*a[1]}if(ar<0)P.reverse();
 const n=P.length,g=geo(),z0=depth/2,zi=z0-bev,en=[];for(let i=0;i<n;i++){const a=P[i],b=P[(i+1)%n],dx=b[0]-a[0],dy=b[1]-a[1],l=Math.hypot(dx,dy)||1;en.push([dy/l,-dx/l])}
 const ins=P.map((p,i)=>{const n1=en[(i+n-1)%n],n2=en[i];let m=[-(n1[0]+n2[0]),-(n1[1]+n2[1])];const l=Math.hypot(m[0],m[1])||1;m=[m[0]/l,m[1]/l];const c=Math.max(.4,-(m[0]*n1[0]+m[1]*n1[1]));return[p[0]+m[0]*bev/c,p[1]+m[1]*bev/c]});
 const tri=earcut(ins),mn=Math.min(...P.map(p=>p[1])),mx=Math.max(...P.map(p=>p[1])),mxx=Math.min(...P.map(p=>p[0])),wx=Math.max(...P.map(p=>p[0]))-mxx||1,hy=mx-mn||1,uv=p=>[(p[0]-mxx)/wx,1-(p[1]-mn)/hy];
 let b=g.p.length/3;ins.forEach(p=>gv(g,p[0],p[1],z0,0,0,1,...uv(p)));for(let k=0;k<tri.length;k+=3)g.i.push(b+tri[k],b+tri[k+1],b+tri[k+2]);
 b=g.p.length/3;ins.forEach(p=>gv(g,p[0],p[1],-z0,0,0,-1,...uv(p)));for(let k=0;k<tri.length;k+=3)g.i.push(b+tri[k],b+tri[k+2],b+tri[k+1]);
 /* vertex normals around the outline: smooth along curves, split at corners */
 const vn=[];for(let i=0;i<n;i++){const a=en[(i+n-1)%n],c=en[i];vn.push(a[0]*c[0]+a[1]*c[1]>.55?(()=>{const m=[a[0]+c[0],a[1]+c[1]],l=Math.hypot(m[0],m[1])||1;return[[m[0]/l,m[1]/l],[m[0]/l,m[1]/l]]})():[a,c])}
 for(let i=0;i<n;i++){const j=(i+1)%n,na=vn[i][1],nb=vn[j][0],pa=P[i],pb=P[j],ia=ins[i],ib=ins[j],s=i/n;
  b=g.p.length/3;gv(g,pa[0],pa[1],-zi,na[0],na[1],0,s,1);gv(g,pb[0],pb[1],-zi,nb[0],nb[1],0,s,1);gv(g,pb[0],pb[1],zi,nb[0],nb[1],0,s,0);gv(g,pa[0],pa[1],zi,na[0],na[1],0,s,0);g.i.push(b,b+1,b+2,b,b+2,b+3);
  const k=.7071;b=g.p.length/3;gv(g,pa[0],pa[1],zi,na[0]*k,na[1]*k,k,s,0);gv(g,pb[0],pb[1],zi,nb[0]*k,nb[1]*k,k,s,0);gv(g,ib[0],ib[1],z0,nb[0]*k,nb[1]*k,k,s,0);gv(g,ia[0],ia[1],z0,na[0]*k,na[1]*k,k,s,0);g.i.push(b,b+1,b+2,b,b+2,b+3);
  b=g.p.length/3;gv(g,pa[0],pa[1],-zi,na[0]*k,na[1]*k,-k,s,1);gv(g,pb[0],pb[1],-zi,nb[0]*k,nb[1]*k,-k,s,1);gv(g,ib[0],ib[1],-z0,nb[0]*k,nb[1]*k,-k,s,1);gv(g,ia[0],ia[1],-z0,na[0]*k,na[1]*k,-k,s,1);g.i.push(b,b+2,b+1,b,b+3,b+2)}
 return g}
function earcut(P){const idx=P.map((_,i)=>i),out=[],ar=(a,b,c)=>(P[b][0]-P[a][0])*(P[c][1]-P[a][1])-(P[c][0]-P[a][0])*(P[b][1]-P[a][1]);
 const inside=(a,b,c,p)=>ar(a,b,p)>=0&&ar(b,c,p)>=0&&ar(c,a,p)>=0;let guard=0;
 while(idx.length>3&&guard++<4000){let cut=false;for(let k=0;k<idx.length;k++){const a=idx[(k+idx.length-1)%idx.length],b=idx[k],c=idx[(k+1)%idx.length];if(ar(a,b,c)<=1e-10)continue;
   let ok=true;for(const p of idx){if(p===a||p===b||p===c)continue;if(inside(a,b,c,p)){ok=false;break}}if(ok){out.push(a,b,c);idx.splice(k,1);cut=true;break}}
  if(!cut){out.push(idx[0],idx[1],idx[2]);idx.splice(1,1)}}
 if(idx.length===3)out.push(idx[0],idx[1],idx[2]);return out}
/* flat pieces: a plane lying face up (uv follows x and z), a disc with the same mapping, a card-like quad standing in xy facing +z */
function gPlane(w,d,ru=1,rv=1){const g=geo();gv(g,-w/2,0,-d/2,0,1,0,0,0);gv(g,w/2,0,-d/2,0,1,0,ru,0);gv(g,w/2,0,d/2,0,1,0,ru,rv);gv(g,-w/2,0,d/2,0,1,0,0,rv);g.i.push(0,2,1,0,3,2);return g}
function gDisc(r,sg=64,ru=1){const g=geo();gv(g,0,0,0,0,1,0,.5*ru,.5*ru);for(let j=0;j<=sg;j++){const a=j/sg*Math.PI*2,x=Math.cos(a)*r,z=Math.sin(a)*r;gv(g,x,0,z,0,1,0,(x/(2*r)+.5)*ru,(z/(2*r)+.5)*ru)}for(let j=1;j<=sg;j++)g.i.push(0,j+1,j);return g}
function gQuad(w,h,back){const g=geo(),s=back?-1:1;gv(g,-w/2*s,h/2,0,0,0,s,0,0);gv(g,w/2*s,h/2,0,0,0,s,1,0);gv(g,w/2*s,-h/2,0,0,0,s,1,1);gv(g,-w/2*s,-h/2,0,0,0,s,0,1);g.i.push(0,3,2,0,2,1);return g}
function g3Mesh(g){const gl=G3D.gl,n=g.p.length/3,d=new Float32Array(n*8);for(let i=0;i<n;i++){d[i*8]=g.p[i*3];d[i*8+1]=g.p[i*3+1];d[i*8+2]=g.p[i*3+2];d[i*8+3]=g.n[i*3];d[i*8+4]=g.n[i*3+1];d[i*8+5]=g.n[i*3+2];d[i*8+6]=g.u[i*2];d[i*8+7]=g.u[i*2+1]}
 const big=n>65535&&G3D.u32,vb=gl.createBuffer(),ib=gl.createBuffer();G3D.bound=null;gl.bindBuffer(gl.ARRAY_BUFFER,vb);gl.bufferData(gl.ARRAY_BUFFER,d,gl.STATIC_DRAW);
 gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,ib);gl.bufferData(gl.ELEMENT_ARRAY_BUFFER,big?new Uint32Array(g.i):new Uint16Array(g.i),gl.STATIC_DRAW);return{vb,ib,n:g.i.length,it:big?gl.UNSIGNED_INT:gl.UNSIGNED_SHORT}}
/* a texture from a canvas; every canvas here is a power of two, so it gets mipmaps */
function g3Tex(cv,{rep=false,af=true}={}){const gl=G3D.gl,t=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,t);gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL,false);
 gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,cv);gl.generateMipmap(gl.TEXTURE_2D);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR_MIPMAP_LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);
 const w=rep?(rep==='m'?gl.MIRRORED_REPEAT:gl.REPEAT):gl.CLAMP_TO_EDGE;gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,w);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,w);
 if(af&&G3D.af)gl.texParameterf(gl.TEXTURE_2D,G3D.af.TEXTURE_MAX_ANISOTROPY_EXT,Math.min(8,G3D.afM||1));return t}
/* a material: colour (sRGB hex), texture, region of the texture, shininess, specular, gloss (how much it mirrors the room) */
function g3Mat(o={}){return{c:lin(o.c||'#ffffff'),t:o.t||null,uv:o.uv||[0,0,1,1],sh:o.sh??30,sp:o.sp??.25,gl:o.gl??.15,a:o.a??1,unlit:!!o.unlit,cut:!!o.cut,e:o.e?lin(o.e):[0,0,0],add:!!o.add,two:!!o.two,vary:!!o.vary}}

/* ---------- scenes: static furniture, moving objects matched across states, flat marks ---------- */
function g3Scene(o){return Object.assign({statics:[],models:{},objs:new Map(),marks:[],seq:0,
 cam:{yaw:0,pitch:.95,fov:.62,tgt:[0,0,0],box:[[-5,0,-5],[5,1,5]],dy:0,dp:0,dz:1,fk:'',fd:20},
 light:{d:v3.norm([-.45,1.25,.55]),c:[2.45,2.22,1.92],sky:[.3,.31,.37],gnd:[.13,.09,.06],exp:1.0},spot:[0,0,9,.6],shR:9,shC:[0,0,0],bg:[.045,.033,.028],tap:null},o)}
/* models are lists of parts that share one transform; ext/off give the box used for taps */
function g3Model(sc,name,parts,ext,off=[0,0,0]){sc.models[name]={parts:parts.map(([g,mat,cast])=>({mesh:g.vb?g:g3Mesh(g),mat,cast:cast!==false})),ext,off};return sc.models[name]}
/* bring the scene to a new list of objects. the same key keeps its object; otherwise the nearest object of the same model glides over;
   objects that are gone leave (opt.gone says where to), new ones arrive (d.from says where from) */
function g3Set(sc,list,opt={}){const now=performance.now(),rm=RM(),old=sc.objs,next=new Map(),used=new Set(),pend=[];
 for(const d of list){const o=d.k!=null?old.get('k:'+d.k):null;if(o&&o.m===d.m&&!o.dying){next.set(o.id,o);used.add(o);g3Aim(o,d,now,opt,rm)}else pend.push(d)}
 const free=[...old.values()].filter(o=>!used.has(o)&&!o.dying&&o.anon),pairs=[];
 for(const d of pend)if(d.k==null)for(const o of free)if(o.m===d.m)pairs.push([v3.len(v3.sub(o.p1,d.p)),d,o]);
 pairs.sort((a,b)=>a[0]-b[0]);const took=new Set(),done=new Set();
 for(const[,d,o]of pairs){if(took.has(o)||done.has(d))continue;took.add(o);done.add(d);next.set(o.id,o);g3Aim(o,d,now,opt,rm)}
 for(const o of old.values()){if(next.has(o.id))continue;if(o.dying){next.set(o.id,o);continue}if(used.has(o)||took.has(o))continue;g3Leave(o,opt.gone?opt.gone(o):null,now,rm,opt);next.set(o.id,o)}
 for(const d of pend){if(done.has(d))continue;const o={id:d.k!=null?'k:'+d.k:'a'+(++sc.seq),anon:d.k==null,m:d.m,p:d.p.slice(),q:(d.q||qt.id()).slice(),s:d.s??1,a:d.a??1,p1:d.p.slice()};g3Spawn(o,d,now,rm,opt);g3Props(o,d);next.set(o.id,o)}
 sc.objs=next;g3Need()}
function g3Props(o,d){o.dim=d.dim??1;o.glow=d.glow||null;o.pick=d.pick||null;o.uv=d.uv||null;o.cast=d.cast!==false;o.lift=d.lift||0;o.drag=!!d.drag;o.refl=d.refl!==false}
function g3Aim(o,d,now,opt,rm){g3Props(o,d);const q1=d.q||qt.id(),s1=d.s??1,a1=d.a??1,dist=v3.len(v3.sub(o.p1,d.p));
 if(dist<1e-4&&qt.same(o.q1||o.q,q1)&&sDiff(o.s1??o.s,s1)<1e-4&&Math.abs((o.a1??o.a)-a1)<1e-3&&!d.path&&!d.spin)return;
 o.p1=d.p.slice();o.q1=q1;o.s1=s1;o.a1=a1;if(rm){o.p=d.p.slice();o.q=q1.slice();o.s=s1;o.a=a1;o.tw=null;return}
 const far=v3.len(v3.sub(o.p,d.p)),dur=d.dur??(opt.dur?opt.dur(o,d,far):Math.min(700,260+90*Math.sqrt(far))),arc=d.arc??(far>.7?Math.min(1.5,.3+far*.13):0);
 o.tw={t0:now+(d.delay??(opt.delay?opt.delay(o,d):0)),d:dur,p0:o.p.slice(),q0:o.q.slice(),s0:o.s,a0:o.a,p1:d.p.slice(),q1,s1,a1,arc,path:d.path?[o.p.slice(),...d.path]:null,hops:d.hops||null,spin:d.spin||null,ez:d.ez||null,land:far>.12}}
function g3Leave(o,g,now,rm,opt){o.dying=1;o.pick=null;if(rm){o.tw={t0:now,d:1,p0:o.p,q0:o.q,s0:o.s,a0:0,p1:o.p,q1:o.q,s1:o.s,a1:0};return}
 const p1=g&&g.p?g.p:v3.add(o.p,[0,.4,0]);o.tw={t0:now+(g&&g.delay||0),d:g&&g.dur||420,p0:o.p.slice(),q0:o.q.slice(),s0:o.s,a0:o.a,p1,q1:g&&g.q||o.q,s1:g&&g.s!=null?g.s:o.s,a1:g&&g.a!=null?g.a:0,arc:g&&g.arc||0}}
function g3Spawn(o,d,now,rm,opt){o.p1=d.p.slice();o.q1=(d.q||qt.id()).slice();o.s1=d.s??1;o.a1=d.a??1;if(rm||d.now)return;
 const f=d.from||(opt.from?opt.from(d):null)||{p:v3.add(d.p,[0,.5,0]),a:0};o.p=(f.p||d.p).slice();o.q=(f.q||o.q1).slice();o.s=f.s??o.s1;o.a=f.a??1;
 o.tw={t0:now+(d.delay??f.delay??0),d:d.dur??f.dur??480,p0:o.p.slice(),q0:o.q.slice(),s0:o.s,a0:o.a,p1:o.p1,q1:o.q1,s1:o.s1,a1:o.a1,arc:d.arc??f.arc??0,path:d.path?[o.p.slice(),...d.path]:null,hops:d.hops||null,spin:d.spin||null,ez:d.ez||null,land:!!(d.from||d.path)}}
function g3Tick(sc,now){let busy=false;const c=sc.cam;
 if(sc.intro){const I=sc.intro,k=Math.min(1,(now-I.t0)/I.d),e=1-Math.pow(1-k,3);c.dy=I.dy*(1-e);c.dp=I.dp*(1-e);c.dz=I.dz+(1-I.dz)*e;if(k>=1){c.dy=c.dp=0;c.dz=1;sc.intro=null}else busy=true}
 if(sc.fx&&sc.fx.length){sc.fx=sc.fx.filter(f=>now-f.t0<f.d);if(sc.fx.length)busy=true}
 for(const o of sc.objs.values()){const t=o.tw;if(!t)continue;let k=(now-t.t0)/t.d;if(k<0){busy=true;continue}if(k>1)k=1;const e=t.ez==='out'?easeOut(k):ease(k);
  if(t.path){const P=t.path,ls=[];let tot=0;for(let i=1;i<P.length;i++){const l=v3.len(v3.sub(P[i],P[i-1]));ls.push(l);tot+=l}let x=e*tot,i=0;while(i<ls.length-1&&x>ls[i]){x-=ls[i];i++}
   const u=ls[i]?Math.min(1,x/ls[i]):1,h=t.hops?t.hops[i]??0:t.arc;o.p=v3.lerp(P[i],P[i+1],u);o.p[1]+=h*4*u*(1-u)}
  else{o.p=v3.lerp(t.p0,t.p1,e);if(t.arc)o.p[1]+=t.arc*4*e*(1-e)}
  o.q=qt.slerp(t.q0,t.q1,e);if(t.spin)o.q=qt.mul(o.q,qt.ax(t.spin[0],t.spin[1],t.spin[2],t.spin[3]*Math.PI*2*(1-e)));
  o.s=sLerp(t.s0,t.s1,e);o.a=t.a0+(t.a1-t.a0)*e;
  if(k>=1){o.tw=null;o.p=t.p1.slice();o.q=t.q1.slice();if(o.dying)sc.objs.delete(o.id);else if(t.land){const md=sc.models[o.m];if(md&&md.land)try{md.land(o,sc)}catch(e){}}}else busy=true}
 return busy}
/* short effects drawn like marks: a ring where a piece lands, sparks when one is taken */
function g3Fx(sc,f){f.t0=performance.now()+(f.delay||0);f.d=f.d||450;(sc.fx||(sc.fx=[])).push(f);g3Need()}
function g3Ripple(sc,p,size=1,c,a=.55){if(RM())return;g3Fx(sc,{m:'mk',uv:MK.ring,c:c||[1,.92,.75],p,s0:size*.35,s1:size*1.35,a0:a,a1:0,d:520,add:true})}
function g3Sparks(sc,p,c,n=10,delay=0){if(RM())return;for(let k=0;k<n;k++){const a=k/n*Math.PI*2+Math.random()*.4,r=.7+Math.random()*.8;g3Fx(sc,{m:'mk',uv:MK.dot,c:c||[1,.8,.4],p:p.slice(),v:[Math.cos(a)*r,.12,Math.sin(a)*r],s0:.28,s1:.06,a0:1,a1:0,d:420+Math.random()*260,add:true,delay})}
 g3Fx(sc,{m:'mk',uv:MK.ring,c:[1,.75,.35],p:p.slice(),s0:.3,s1:2,a0:.7,a1:0,d:560,add:true,delay})}

/* ---------- camera: orbit around the board, fit the board to whatever shape the screen has ---------- */
function g3Dir(c){const tall=(G3D.asp||1)<.8,yaw=c.yaw+c.dy,pit=clamp(c.pitch+(tall?c.pp||0:0)+c.dp,.32,1.5);return[Math.sin(yaw)*Math.cos(pit),Math.sin(pit),Math.cos(yaw)*Math.cos(pit)]}
function g3Shift(c){const W=G3D.cw||1,H=G3D.ch||1,i=c.inset||{t:0,b:0,l:0,r:0};return{cx:(i.l-i.r)/W,cy:(i.b-i.t)/H,hx:Math.max(.3,1-(i.l+i.r)/W),hy:Math.max(.3,1-(i.t+i.b)/H)}}
function g3Fit(c,dir,asp,sh){const B=asp<.8&&c.boxp?c.boxp:c.box,pts=[];for(const x of[B[0][0],B[1][0]])for(const y of[B[0][1],B[1][1]])for(const z of[B[0][2],B[1][2]])pts.push([x,y,z]);
 const tall=asp<.8,P=m4.persp(c.fov,asp,.05,500),mx=(tall?c.mxp??.985:c.mx??.94)*sh.hx,my=(c.my??.92)*sh.hy,B0=tall&&c.boxp?c.boxp:c.box;P[8]=-sh.cx;P[9]=-sh.cy;let lo=1,hi=400;
 for(let it=0;it<26;it++){const d=(lo+hi)/2,e=v3.add(c.tgt,v3.mul(dir,d)),VP=m4.mul(P,m4.look(e,c.tgt,[0,1,0]));let ok=true;
  for(const p of pts){const r=m4.xf(VP,p);if(r[3]<=0||Math.abs(r[0]-sh.cx)>mx||Math.abs(r[1]-sh.cy)>my){ok=false;break}}if(ok)hi=d;else lo=d}
 return hi}
function g3Cam(sc){const c=sc.cam,asp=G3D.asp||1,dir=g3Dir(c),sh=g3Shift(c),key=[asp.toFixed(3),c.yaw,c.dy.toFixed(3),c.dp.toFixed(3),c.pitch,c.fov,JSON.stringify(c.box),JSON.stringify(c.inset||0)].join();
 if(c.fk!==key){c.fd=g3Fit(c,dir,asp,sh);c.fk=key}
 if(c.fdc==null||c.snap){c.fdc=c.fd;c.cxc=sh.cx;c.cyc=sh.cy;c.snap=0}else{const k=.2;c.fdc+=(c.fd-c.fdc)*k;c.cxc+=(sh.cx-c.cxc)*k;c.cyc+=(sh.cy-c.cyc)*k;
  if(Math.abs(c.fd-c.fdc)>c.fd*.002||Math.abs(sh.cx-c.cxc)>.002||Math.abs(sh.cy-c.cyc)>.002)sc.camBusy=true;else{c.fdc=c.fd;c.cxc=sh.cx;c.cyc=sh.cy}}
 const dist=c.fdc/c.dz,eye=v3.add(c.tgt,v3.mul(dir,dist)),V=m4.look(eye,c.tgt,[0,1,0]),P=m4.persp(c.fov,asp,Math.max(.2,dist*.2),dist*3+30);P[8]=-c.cxc;P[9]=-c.cyc;
 return{eye,VP:m4.mul(P,V),dist,cx:c.cxc,cy:c.cyc}}
/* how much of the screen the floating panels cover, so the board sits in the free part */
function g3Insets(sc){const cv=G3D.cv,gx=cv&&cv.isConnected&&cv.closest('.gx'),c=sc.cam;if(!gx){c.inset=null;return}const r=cv.getBoundingClientRect();if(!r.width||!r.height)return;
 const top=gx.querySelector('.ghud.top'),bot=gx.querySelector('.ghud.bot'),tr=top&&top.getBoundingClientRect();let t=0,b=0,rr=0;
 const vis=el=>el&&[...el.children].filter(x=>x.offsetHeight&&getComputedStyle(x).position!=='absolute');
 if(tr&&tr.left>r.left+r.width*.3)rr=r.right-tr.left;
 else{const lt=vis(top).pop(),fb=vis(bot)[0],gt=gx.getBoundingClientRect().top,ct=r.top-gt;if(lt)t=g3Lay(lt,gx)+lt.offsetHeight-ct+8;if(fb)b=ct+r.height-g3Lay(fb,gx)+8}
 const q=(v,m)=>Math.round(clamp(v,0,m)/8)*8;c.inset={t:q(t,r.height*.4),b:q(b,r.height*.48),l:0,r:q(rr,r.width*.5)};G3D.cw=r.width;G3D.ch=r.height}

/* ---------- drawing ---------- */
let G3_LID=null;
function g3Bind(m){const gl=G3D.gl;if(G3D.bound===m)return;G3D.bound=m;gl.bindBuffer(gl.ARRAY_BUFFER,m.vb);gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,m.ib);
 gl.enableVertexAttribArray(0);gl.vertexAttribPointer(0,3,gl.FLOAT,false,32,0);gl.enableVertexAttribArray(1);gl.vertexAttribPointer(1,3,gl.FLOAT,false,32,12);gl.enableVertexAttribArray(2);gl.vertexAttribPointer(2,2,gl.FLOAT,false,32,24)}
function g3Part(pt,M,dim,glow,al,sh,uv){const gl=G3D.gl,u=G3D.P.u,m=pt.mat;gl.uniformMatrix4fv(u.uM,false,M);gl.uniform4fv(u.uUV,m.vary&&uv?uv:m.uv);
 gl.uniform3f(u.uC,m.c[0]*dim,m.c[1]*dim,m.c[2]*dim);const e=glow||m.e;gl.uniform3f(u.uE,e[0],e[1],e[2]);gl.uniform4f(u.uMat,m.sh,m.sp,m.gl,m.a*al);gl.uniform4f(u.uFx,m.t?1:0,m.unlit?1:0,m.cut?1:0,sh?1:0);
 gl.bindTexture(gl.TEXTURE_2D,m.t||G3D.white);if(m.two)gl.disable(gl.CULL_FACE);g3Bind(pt.mesh);gl.drawElements(gl.TRIANGLES,pt.mesh.n,pt.mesh.it,0);if(m.two)gl.enable(gl.CULL_FACE)}
function g3Draw(sc,now){const gl=G3D.gl,cv=G3D.cv,C=g3Cam(sc),L=sc.light;sc.camNow=C;G3D.bound=null;
 for(const o of sc.objs.values())o.M=m4.trs(o.lift?v3.add(o.p,[0,o.lift,0]):o.p,o.q,o.s);
 const sm=G3D.sm&&sc.shadow!==false?G3D.sm:null;let LVP=G3_LID||(G3_LID=m4.id());
 if(sm){const c=sc.shC,R=sc.shR,e=v3.add(c,v3.mul(L.d,R*3));LVP=m4.mul(m4.ortho(-R,R,-R,R,R*.5,R*6),m4.look(e,c,Math.abs(L.d[1])>.99?[0,0,-1]:[0,1,0]));
  gl.bindFramebuffer(gl.FRAMEBUFFER,sm.fb);gl.viewport(0,0,sm.S,sm.S);gl.clearColor(1,1,1,1);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);
  gl.enable(gl.DEPTH_TEST);gl.depthMask(true);gl.disable(gl.BLEND);gl.enable(gl.CULL_FACE);gl.cullFace(gl.FRONT);const Q=G3D.Q;gl.useProgram(Q.p);gl.uniformMatrix4fv(Q.u.uL,false,LVP);
  const one=(mesh,M)=>{gl.uniformMatrix4fv(Q.u.uM,false,M);g3Bind(mesh);gl.drawElements(gl.TRIANGLES,mesh.n,mesh.it,0)};
  for(const s of sc.statics)if(s.cast)for(const pt of s.parts)if(pt.cast)one(pt.mesh,s.M);
  for(const o of sc.objs.values()){if(o.a<.55||!o.cast)continue;const md=sc.models[o.m];if(md)for(const pt of md.parts)if(pt.cast)one(pt.mesh,o.M)}
  gl.bindFramebuffer(gl.FRAMEBUFFER,null);gl.cullFace(gl.BACK)}
 gl.viewport(0,0,cv.width,cv.height);gl.clearColor(sc.bg[0],sc.bg[1],sc.bg[2],1);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);
 const P=G3D.P,u=P.u;gl.useProgram(P.p);gl.uniformMatrix4fv(u.uVP,false,C.VP);gl.uniformMatrix4fv(u.uL,false,LVP);gl.uniform3fv(u.uEye,C.eye);gl.uniform3fv(u.uLd,L.d);gl.uniform3fv(u.uLc,L.c);
 gl.uniform3fv(u.uSky,L.sky);gl.uniform3fv(u.uGnd,L.gnd);gl.uniform1f(u.uExp,L.exp);gl.uniform4fv(u.uSp,sc.spot);
 gl.activeTexture(gl.TEXTURE1);gl.bindTexture(gl.TEXTURE_2D,sm?sm.t:G3D.white);gl.uniform1i(u.uSh,1);gl.uniform1f(u.uSS,sm?1/sm.S:0);gl.activeTexture(gl.TEXTURE0);gl.uniform1i(u.uT,0);
 gl.enable(gl.DEPTH_TEST);gl.depthMask(true);gl.disable(gl.BLEND);gl.enable(gl.CULL_FACE);gl.cullFace(gl.BACK);
 for(const s of sc.statics){if(s.late)continue;for(const pt of s.parts)g3Part(pt,s.M,1,null,1,!!sm&&s.recv!==false)}
 if(sc.refl){const R=sc.refl,Mi=m4.id(),me=[C.eye[0],2*R.y-C.eye[1],C.eye[2]];Mi[5]=-1;Mi[13]=2*R.y;
  gl.uniform3fv(u.uEye,me);gl.uniform3f(u.uLd,L.d[0],-L.d[1],L.d[2]);gl.uniform4f(u.uRf,R.k,R.y,R.fade||1.2,0);gl.uniform4fv(u.uRc,R.rect);gl.uniform3fv(u.uRe,C.eye);
  gl.disable(gl.DEPTH_TEST);gl.enable(gl.BLEND);gl.blendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA);gl.cullFace(gl.FRONT);
  const rl=[...sc.objs.values()].filter(o=>o.a>.5&&o.refl&&o.p[1]>=R.y-.02&&o.p[0]>R.rect[0]-.6&&o.p[0]<R.rect[2]+.6&&o.p[2]>R.rect[1]-.6&&o.p[2]<R.rect[3]+.6).sort((a,b)=>v3.len(v3.sub(b.p,me))-v3.len(v3.sub(a.p,me)));
  for(const o of rl){const md=sc.models[o.m];if(!md)continue;const M=m4.mul(Mi,o.M);for(const pt of md.parts)if(!pt.mat.unlit)g3Part(pt,M,o.dim,o.glow,1,false,o.uv)}
  gl.uniform4f(u.uRf,0,0,0,0);gl.uniform3fv(u.uEye,C.eye);gl.uniform3fv(u.uLd,L.d);gl.cullFace(gl.BACK);gl.enable(gl.DEPTH_TEST);gl.disable(gl.BLEND)}
 const HOV=[.1,.07,.02],tr=[];for(const o of sc.objs.values()){const md=sc.models[o.m];if(!md||o.a<.01)continue;if(o.a<.999){tr.push(o);continue}const gw=o.glow||(sc.hov===o.id?HOV:null);for(const pt of md.parts)g3Part(pt,o.M,o.dim,gw,1,!!sm,o.uv)}
 gl.enable(gl.BLEND);gl.depthMask(false);gl.enable(gl.POLYGON_OFFSET_FILL);gl.polygonOffset(-1,-4);
 const pulse=.62+.38*Math.sin(now*.0055);
 const one=(mk,M,al)=>{const md=sc.models[mk.m];if(!md)return;if(mk.add)gl.blendFunc(gl.SRC_ALPHA,gl.ONE);else gl.blendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA);const pt=md.parts[0],m=pt.mat,c0=m.c;if(mk.c)m.c=mk.c;g3Part(pt,M,1,null,al,false,mk.uv);m.c=c0};
 for(const mk of sc.hm?[...sc.marks,sc.hm]:sc.marks)one(mk,mk.M||(mk.M=m4.trs(mk.p,mk.q||qt.id(),mk.s||1)),(mk.a??1)*(mk.pulse&&!RM()?pulse:1));
 if(sc.fx)for(const f of sc.fx){const k=(now-f.t0)/f.d;if(k<0||k>1)continue;const e=easeOut(k),s=f.s0+(f.s1-f.s0)*e,p=f.v?v3.add(f.p,v3.mul(f.v,e)):f.p;one(f,m4.trs(p,f.q||qt.id(),s),f.a0+(f.a1-f.a0)*e)}
 gl.disable(gl.POLYGON_OFFSET_FILL);gl.blendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA);gl.depthMask(true);
 for(const s of sc.statics)if(s.late)for(const pt of s.parts)g3Part(pt,s.M,1,null,1,!!sm&&s.recv!==false);
 gl.depthMask(false);tr.sort((a,b)=>v3.len(v3.sub(b.p,C.eye))-v3.len(v3.sub(a.p,C.eye)));
 for(const o of tr){const md=sc.models[o.m];for(const pt of md.parts)g3Part(pt,o.M,o.dim,o.glow,o.a,!!sm,o.uv)}
 gl.depthMask(true);gl.disable(gl.BLEND)}
/* names and scores float over the table at points projected from the 3D seats */
/* where an element sits in the game screen by layout alone (slides and animations do not count) */
function g3Lay(el,root){let y=0,e=el;while(e&&e!==root){y+=e.offsetTop;e=e.offsetParent}return y}
/* tall screens leave room above and below a board: the two players' plates move in to sit just off its edges, as in chess apps.
   the offsets live on the view, so a new render of the game screen starts with them and nothing jumps */
function g3Hug(sc){const cv=G3D.cv,gx=cv&&cv.isConnected&&cv.closest('.gx'),C=sc.camNow;let T=0,B=0;
 if(gx&&C&&sc.hug&&(G3D.asp||1)<.8){const H=cv.clientHeight,ct=cv.getBoundingClientRect().top-gx.getBoundingClientRect().top,c=sc.cam,bx=c.box;let y0=1e9,y1=-1e9;
  for(const x of[bx[0][0],bx[1][0]])for(const y of[bx[0][1],bx[1][1]])for(const z of[bx[0][2],bx[1][2]]){const q=m4.xf(C.VP,[x,y,z]);if(q[3]<=0)continue;const py=(1-q[1])/2*H+ct;if(py<y0)y0=py;if(py>y1)y1=py}
  const tg=[...gx.querySelectorAll('.ghud.top>.pl,.ghud.top>.mvs')].filter(e=>e.offsetHeight).pop(),bg=gx.querySelector('.ghud.bot>.pl');
  if(tg&&y0<1e9)T=Math.max(0,Math.round((y0-4-g3Lay(tg,gx)-tg.offsetHeight)/2)*2);
  if(bg&&y1>-1e9)B=Math.max(0,Math.round((g3Lay(bg,gx)-y1-4)/2)*2)}
 if(G3D.hugT!==T||G3D.hugB!==B){G3D.hugT=T;G3D.hugB=B;view.style.setProperty('--hugT',T+'px');view.style.setProperty('--hugB',B+'px')}view.classList.toggle('ghug',T>0||B>0)}
function g3Labels(sc){g3Hug(sc);const C=sc.camNow,cv=G3D.cv,root=cv&&cv.parentNode&&cv.parentNode.parentNode;if(!C||!root||!sc.anchors)return;const W=root.clientWidth,H=root.clientHeight;if(!W||!H)return;
 for(const[sel,p]of sc.anchors){const el=root.querySelector(sel);if(!el)continue;const r=m4.xf(C.VP,p);if(r[3]<=0)continue;const w=el.offsetWidth/2+6,h=el.offsetHeight/2+6;
  el.style.left=clamp((r[0]*.5+.5)*W,w,W-w).toFixed(1)+'px';el.style.top=clamp((.5-r[1]*.5)*H,h,H-h).toFixed(1)+'px'}}
function g3Need(){if(!G3D.raf&&G3D.ok)G3D.raf=requestAnimationFrame(g3Frame)}
function g3Frame(now){G3D.raf=0;const sc=G3D.sc,cv=G3D.cv;if(!sc||!cv||!cv.isConnected||!G3D.ok)return;const busy=g3Tick(sc,now);g3Size();sc.camBusy=false;
 try{g3Draw(sc,now);g3Labels(sc)}catch(e){try{console.warn('3D draw',e)}catch(x){}return}
 if(busy||sc.camBusy)g3Need();else if(!RM()&&sc.marks.some(m=>m.pulse)){clearTimeout(G3D.slow);G3D.slow=setTimeout(g3Need,80)}}
function g3Size(){const cv=G3D.cv,el=cv.parentNode;if(!el)return;const r=el.getBoundingClientRect(),d=Math.min(window.devicePixelRatio||1,2),w=Math.max(2,Math.round(r.width*d)),h=Math.max(2,Math.round(r.height*d));
 if(cv.width!==w||cv.height!==h){cv.width=w;cv.height=h}G3D.asp=w/h}
/* put the canvas into a board on screen and draw at once, so there is no empty frame */
function g3Mount(el,sc){if(!g3Init())return false;const cv=G3D.cv;if(cv.parentNode!==el)el.prepend(cv);G3D.sc=sc;
 if(window.ResizeObserver){if(!G3D.ro)G3D.ro=new ResizeObserver(()=>{if(G3D.sc&&G3D.cv.isConnected){g3Size();g3Insets(G3D.sc);G3D.sc.cam.snap=1;g3Draw(G3D.sc,performance.now());g3Labels(G3D.sc)}});G3D.ro.disconnect();G3D.ro.observe(el)}
 el.classList.toggle('moved',!sc.intro&&!!(sc.cam.dy||sc.cam.dp||sc.cam.dz!==1));g3Size();g3Insets(sc);try{g3Draw(sc,performance.now());g3Labels(sc)}catch(e){}g3Need();return true}
function g3Reset(){const sc=G3D.sc;if(!sc)return;const c=sc.cam,a={dy:c.dy,dp:c.dp,dz:c.dz},t0=performance.now();
 const f=t=>{const k=Math.min(1,(t-t0)/380),e=easeOut(k);c.dy=a.dy*(1-e);c.dp=a.dp*(1-e);c.dz=a.dz+(1-a.dz)*e;g3Moved(true);if(k<1)requestAnimationFrame(f);else{c.dy=c.dp=0;c.dz=1;g3Moved(true)}};requestAnimationFrame(f)}
A.g3reset=()=>g3Reset();
function g3Moved(){const sc=G3D.sc,el=G3D.cv&&G3D.cv.parentNode;if(el&&sc)el.classList.toggle('moved',!sc.intro&&(Math.abs(sc.cam.dy)>.01||Math.abs(sc.cam.dp)>.01||Math.abs(sc.cam.dz-1)>.01));g3Need()}
/* the camera swoops in when a game opens */
function g3StartIntro(sc){if(RM())return;const s=Math.random()<.5?1:-1;sc.intro={t0:performance.now(),d:1500,dy:.6*s,dp:.55,dz:.62};sc.cam.dy=.6*s;sc.cam.dp=.55;sc.cam.dz=.62;g3Need()}

/* ---------- touch: drag turns the board, two fingers zoom, a tap picks ---------- */
function g3Ray(cx,cy){const sc=G3D.sc,r=G3D.cv.getBoundingClientRect(),C=sc.camNow||g3Cam(sc),nx=(cx-r.left)/r.width*2-1-(C.cx||0),ny=1-(cy-r.top)/r.height*2-(C.cy||0);
 const f=v3.norm(v3.sub(sc.cam.tgt,C.eye)),rt=v3.norm(v3.cross(f,[0,1,0])),up=v3.cross(rt,f),t=Math.tan(sc.cam.fov/2);
 return{o:C.eye,d:v3.norm(v3.add(f,v3.add(v3.mul(rt,nx*t*G3D.asp),v3.mul(up,ny*t))))}}
/* the nearest object with tap data under the ray, tested against its box */
function g3HitObj(sc,ray,filter){let best=null,bt=1e9;for(const o of sc.objs.values()){if(!o.pick||o.dying||(filter&&!filter(o)))continue;const md=sc.models[o.m];if(!md||!md.ext)continue;
  const iq=qt.inv(o.q),s=o.s||1,ro=v3.mul(qt.rot(iq,v3.sub(o.lift?v3.add(o.p,[0,o.lift,0]):o.p,ray.o)),-1/s),rd=v3.mul(qt.rot(iq,ray.d),1/s);
  let t0=-1e9,t1=1e9;for(let k=0;k<3;k++){const lo=md.off[k]-md.ext[k],hi=md.off[k]+md.ext[k];if(Math.abs(rd[k])<1e-9){if(ro[k]<lo||ro[k]>hi){t0=1e9;break}continue}
   let a=(lo-ro[k])/rd[k],b=(hi-ro[k])/rd[k];if(a>b)[a,b]=[b,a];t0=Math.max(t0,a);t1=Math.min(t1,b)}
  if(t0<=t1&&t1>0&&t0<bt){bt=t0;best=o}}return best}
const g3HitY=(ray,y)=>{if(Math.abs(ray.d[1])<1e-6)return null;const t=(y-ray.o[1])/ray.d[1];return t>0?v3.add(ray.o,v3.mul(ray.d,t)):null};
/* one finger on your own piece drags it; anywhere else it turns the board; two fingers zoom; a short touch is a tap */
function g3Input(cv){const P=new Map();let st=null,pin=null,hovT=0;
 const back=o=>{if(!o||o.tw||o.dying)return;if(v3.len(v3.sub(o.p,o.p1))>.01){o.tw={t0:performance.now(),d:230,p0:o.p.slice(),q0:o.q.slice(),s0:o.s,a0:o.a,p1:o.p1.slice(),q1:(o.q1||o.q).slice(),s1:o.s1??o.s,a1:o.a1??o.a,arc:0,land:true};g3Need()}};
 cv.addEventListener('pointerdown',e=>{const sc=G3D.sc;if(!sc)return;P.set(e.pointerId,[e.clientX,e.clientY]);if(sc.intro){sc.intro=null;g3Moved()}
  if(P.size===1){let obj=null;if(sc.drag){try{obj=g3HitObj(sc,g3Ray(e.clientX,e.clientY),o=>o.drag)}catch(x){}}st={x:e.clientX,y:e.clientY,dy:sc.cam.dy,dp:sc.cam.dp,drag:false,obj}}
  else if(P.size===2){if(st&&st.obj&&st.drag){st.obj.held=0;back(st.obj);sc.hm=null}st=null;const[a,b]=[...P.values()];pin={d:Math.hypot(a[0]-b[0],a[1]-b[1])||1,z:sc.cam.dz}}});
 cv.addEventListener('pointermove',e=>{const sc=G3D.sc;if(!sc)return;
  if(!P.has(e.pointerId)){if(e.pointerType==='mouse'&&!e.buttons&&performance.now()-hovT>45){hovT=performance.now();let h=null;try{h=g3HitObj(sc,g3Ray(e.clientX,e.clientY),o=>o.drag||(o.pick&&sc.hoverAll))}catch(x){}const id=h?h.id:null;if(id!==sc.hov){sc.hov=id;cv.style.cursor=h?'pointer':'';g3Need()}}return}
  P.set(e.pointerId,[e.clientX,e.clientY]);
  if(P.size===2&&pin){const[a,b]=[...P.values()];sc.cam.dz=clamp(pin.z*Math.hypot(a[0]-b[0],a[1]-b[1])/pin.d,.85,1.9);g3Moved();return}
  if(!st)return;const dx=e.clientX-st.x,dy=e.clientY-st.y;
  if(!st.drag&&Math.hypot(dx,dy)>(st.obj?7:9)){st.drag=true;try{cv.setPointerCapture(e.pointerId)}catch(x){}if(st.obj){st.obj.held=1;try{sc.drag.start&&sc.drag.start(st.obj)}catch(x){}if(typeof gBuzz==='function')gBuzz(6)}}
  if(!st.drag)return;
  if(st.obj){const D=sc.drag,p=g3HitY(g3Ray(e.clientX,e.clientY),D.y);if(p){const o=st.obj;o.tw=null;o.p=[p[0],D.y+(D.lift??.55),p[2]+(D.dz||0)];try{sc.hm=D.move?D.move(o,p):null}catch(x){}g3Need()}return}
  if(sc.orbit!==false){sc.cam.dy=clamp(st.dy-dx*.0065,-(sc.yawMax??.75),sc.yawMax??.75);sc.cam.dp=clamp(st.dp+dy*.005,-(sc.pitchDown??.42),sc.pitchUp??.45);g3Moved()}});
 const up=e=>{const had=P.delete(e.pointerId);if(P.size<2)pin=null;if(!had||!st)return;const s=st;st=null;const sc=G3D.sc;
  if(s.obj&&s.drag){const o=s.obj;o.held=0;if(sc)sc.hm=null;if(e.type==='pointerup'&&sc&&sc.drag){let p=null;try{p=g3HitY(g3Ray(e.clientX,e.clientY),sc.drag.y)}catch(x){}try{sc.drag.drop(o,p)}catch(x){}}back(o);g3Need();return}
  if(e.type==='pointerup'&&!s.drag)g3Tap(e.clientX,e.clientY)};
 cv.addEventListener('pointerup',up);cv.addEventListener('pointercancel',up);cv.addEventListener('lostpointercapture',e=>{if(P.has(e.pointerId)&&e.pointerType==='mouse')up(e)});
 cv.addEventListener('pointerleave',()=>{const sc=G3D.sc;if(sc&&sc.hov){sc.hov=null;cv.style.cursor='';g3Need()}});
 cv.addEventListener('wheel',e=>{const sc=G3D.sc;if(!sc||!(cv.closest('.gx')||e.ctrlKey))return;e.preventDefault();sc.cam.dz=clamp(sc.cam.dz*Math.exp(-e.deltaY*.0012),.85,1.9);g3Moved()},{passive:false});
 cv.addEventListener('contextmenu',e=>e.preventDefault())}
function g3Tap(x,y){const sc=G3D.sc;if(!sc||!sc.tap)return;try{sc.tap(g3Ray(x,y))}catch(e){}}
/* call a game action the same way a button on the flat board would */
const g3Act=(a,data)=>{if(A[a])A[a]({dataset:data,closest:()=>null})};
