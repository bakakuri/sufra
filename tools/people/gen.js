/* sculpt every part and pack them into one file the game loads: a JSON header, then for each part
   positions (16-bit within its box), normals (8-bit) and triangles (16-bit) */
'use strict';
const fs=require('fs'),S=require('./sdf.js'),P=require('./people.js'),{simplify}=require('./simplify.js'),zlib=require('zlib');
const out=process.argv[2]||require('path').join(__dirname,'../../icons/g/people.bin'),Q=+(process.argv[3]||1);
const HB=[[-1.35,-1.2,-1.45],[1.35,2.75,1.7]];/* head parts, about the pivot (head centre HC above it) */
const parts=[
 ['head_m','face',P.headF(false),HB,.034,.2],['head_f','face',P.headF(true),HB,.034,.2],
 ['hair_short','hair',P.hairF('short'),HB,.04,.2],['hair_curly','hair',P.hairF('curly'),HB,.04,.22],['hair_long','hair',P.hairF('long'),[[-1.6,-1.3,-1.6],[1.6,2.8,1.65]],.045,.18],
 ['hair_pony','hair',P.hairF('pony'),[[-1.35,-.7,-2.0],[1.35,2.8,1.65]],.04,.2],['hair_bald','hair',P.hairF('bald'),HB,.04,.25],
 ['mus','hair',P.musF(),[[-.65,0,.8],[.65,.7,1.5]],.022,.3],['beard','hair',P.beardF(),[[-1.2,-.8,-.55],[1.2,1.1,1.55]],.04,.25],
 ['body_m','knit',P.bodyF(false),[[-2.9,-2.85,-1.3],[2.9,3.0,1.6]],.075,.16],['body_f','knit',P.bodyF(true),[[-2.8,-2.85,-1.3],[2.8,3.0,1.6]],.075,.16],
 ['neck','skin',P.neckF(),[[-.6,2.2,-.5],[.6,3.6,.6]],.05,.3]];
for(const s of[-1,1]){const A=P.armW(s);const lo=[Math.min(0,A.hand[0])-.8,Math.min(0,A.hand[1])-.8,Math.min(0,A.hand[2])-.8],hi=[Math.max(0,A.hand[0])+.8,Math.max(0,A.hand[1])+.8,Math.max(0,A.hand[2])+.8];
 parts.push(['sleeve'+(s<0?'L':'R'),'knit',P.sleeveF(s),[lo,hi],.04,.15]);
 const h=A.hand;parts.push(['hand'+(s<0?'L':'R'),'skin',P.handF(s),[[h[0]-.75,h[1]-.75,h[2]-.75],[h[0]+.75,h[1]+.75,h[2]+.75]],.02,.15])}
const only=process.env.ONLY?process.env.ONLY.split(','):null;
const head=[],bufs=[];let off=0,tot=0;
for(const[name,kind,f,box,step0,ratio]of parts){if(only&&!only.includes(name))continue;const step=step0*Q,t0=Date.now(),m0=S.mesh(f,box[0],box[1],step);
 /* fewer triangles, then normals again from the shape itself at the vertices that are left */
 const sm=simplify(m0.p,m0.i,Math.round(m0.i.length/3*(+process.env.R||ratio))),m={p:sm.p,i:sm.i,n:[]},h=.01;
 for(let k=0;k<m.p.length;k+=3){const x=m.p[k],y=m.p[k+1],z=m.p[k+2],g=S.norm([f([x+h,y,z])-f([x-h,y,z]),f([x,y+h,z])-f([x,y-h,z]),f([x,y,z+h])-f([x,y,z-h])]);m.n.push(g[0],g[1],g[2])}
 /* wind every triangle so it faces where the field grows (outward) */
 let agree=0;for(let k=0;k<m.i.length;k+=3){const a=m.i[k]*3,b=m.i[k+1]*3,c=m.i[k+2]*3,u=[m.p[b]-m.p[a],m.p[b+1]-m.p[a+1],m.p[b+2]-m.p[a+2]],v=[m.p[c]-m.p[a],m.p[c+1]-m.p[a+1],m.p[c+2]-m.p[a+2]],g=S.cross(u,v);agree+=Math.sign(g[0]*m.n[a]+g[1]*m.n[a+1]+g[2]*m.n[a+2])}
 if(agree<0)for(let k=0;k<m.i.length;k+=3){const t=m.i[k+1];m.i[k+1]=m.i[k+2];m.i[k+2]=t}
 const nv=m.p.length/3,mn=[1e9,1e9,1e9],mx=[-1e9,-1e9,-1e9];for(let k=0;k<nv;k++)for(let a=0;a<3;a++){mn[a]=Math.min(mn[a],m.p[k*3+a]);mx[a]=Math.max(mx[a],m.p[k*3+a])}
 const pos=new Uint16Array(nv*3),nor=new Int8Array(nv*4);for(let k=0;k<nv;k++)for(let a=0;a<3;a++){pos[k*3+a]=Math.round((m.p[k*3+a]-mn[a])/((mx[a]-mn[a])||1)*65535);nor[k*4+a]=Math.round(m.n[k*3+a]*127)}
 /* each value stored as the change from the one before: small numbers, which pack well */
 for(let k=nv-1;k>0;k--)for(let a=0;a<3;a++)pos[k*3+a]=(pos[k*3+a]-pos[(k-1)*3+a])&65535;
 const big=false,idx=new Int32Array(m.i.length);for(let k=m.i.length-1;k>=0;k--)idx[k]=m.i[k]-(k?m.i[k-1]:0);
 const pad=b=>{const r=(4-(b.byteLength%4))%4;return r?Buffer.concat([Buffer.from(b.buffer,b.byteOffset,b.byteLength),Buffer.alloc(r)]):Buffer.from(b.buffer,b.byteOffset,b.byteLength)};
 const B=[pad(pos),pad(nor),pad(idx)];head.push({name,kind,nv,ni:m.i.length,big,mn,mx,o:off});for(const b of B){bufs.push(b);off+=b.length}
 tot+=nv;console.log(name.padEnd(12),'verts',String(nv).padStart(6),'tris',String(m.i.length/3).padStart(6),'agree',(agree/(m.i.length/3)).toFixed(2),(Date.now()-t0)+'ms')}
const meta={v:1,HC:P.HC,eye:P.EYE,parts:head},js=Buffer.from(JSON.stringify(meta)),jl=Buffer.alloc(4);jl.writeUInt32LE(js.length);const jp=Buffer.alloc((4-(js.length%4))%4);
const file=Buffer.concat([jl,js,jp,...bufs]),gz=zlib.gzipSync(file,{level:9});fs.writeFileSync(out,gz);console.log('total verts',tot,'bytes',file.length,'gzip',gz.length);
