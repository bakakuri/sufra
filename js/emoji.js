/* the emoji panel: every emoji (about 1900) in groups, each with its sub-groups, opened under a text box: a chat, comments, a post,
   a story's text. A touch puts the emoji where the cursor is and the panel stays open, as a phone's own emoji keyboard does.
   Tabs along the top: the ones used last, "ჩვენებური" (the Georgian table and country), then the groups; a search in Georgian or English;
   a skin tone for people and hands; in a chat and in comments the drawn stickers too.
   The list itself (js/emoji-data.js) comes only when the panel is first opened. A phone that cannot draw an emoji (too new for it)
   does not get it in the list, so there are no empty boxes. Back closes the panel and nothing else */
const EMO={data:null,p:null,inp:null,btn:null,max:99,bad:new Set(),tone:'',rec:[],words:null,flat:null,probed:false};
const EMTONE=['','🏻','🏼','🏽','🏾','🏿'];
const EMOGE='🇬🇪 🍷 🥂 🍾 🍇 🥟 🧀 🫓 🍞 🥖 🍖 🍗 🥩 🍢 🍲 🥘 🥗 🌶️ 🧄 🧅 🥒 🍅 🫑 🌿 🍑 🍒 🍐 🍎 🍉 🍋 🍊 🌰 🥜 🍯 🫖 ☕ 🥛 🍫 🎂 🍰 🧁 🥧 ⛪ 🏰 🏔️ ⛰️ 🌄 🏞️ 🌊 🏖️ 🌲 🌳 🍂 🌹 🌷 🌸 🐎 🐑 🐐 🐄 🐓 🦅 🐻 🐺 🦌 🐝 💃 🕺 🎶 🎵 🪕 🎻 🥁 🎤 ⚔️ 🛡️ 🏹 🐉 ☀️ 🔥 ❤️ 🤍 ❤️‍🔥 🙏 🤝 🥳 🎉 🎊 ⚽ 🏉 🤼 🏆 ♟️ 🃏 🎲 🚗 🚂 🏠 🏡';
try{EMO.tone=EMTONE.includes(store.get('emotone',''))?store.get('emotone',''):'';const r=store.get('emorec',[]);EMO.rec=Array.isArray(r)?r.filter(x=>typeof x==='string').slice(0,40):[]}catch(e){}
/* the list as it should be shown: without a tone (a FE0F where the tone would be), or with the chosen tone */
const emoPlain=s=>s.replace(/\u0000/g,'️').replace(/\u{1F3FB}/gu,'');
const emoToned=(s,t)=>/\u0000|\u{1F3FB}/u.test(s)&&t?s.replace(/\u0000|\u{1F3FB}/gu,t):emoPlain(s);
function emoLoad(){if(EMO.data)return Promise.resolve(EMO.data);if(EMO.ld)return EMO.ld;
 const v=(($('script[src*="/js/core.js"]')||{}).src||'').split('v=')[1]||'';
 EMO.ld=new Promise((res,rej)=>{const s=document.createElement('script');s.src='/js/emoji-data.js'+(v?'?v='+v:'');s.onload=()=>{const d=window.EMD;if(!d){EMO.ld=null;rej(new Error('no data'));return}EMO.data=d;res(d)};s.onerror=()=>{EMO.ld=null;rej(new Error('load'))};document.head.appendChild(s)});return EMO.ld}
/* what this phone can draw: the newest emoji version whose test glyph comes out in colour, and joined emoji (people with a tone,
   a black cat, a rainbow flag) that come out as one glyph and not as their parts side by side */
function emoProbe(){if(EMO.probed)return;EMO.probed=true;try{const c=document.createElement('canvas');c.width=c.height=28;const x=c.getContext('2d',{willReadFrequently:true});
 x.font='22px "Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji","Segoe UI Symbol",sans-serif';x.textBaseline='top';
 const col=e=>{x.clearRect(0,0,28,28);x.fillStyle='#000';x.fillText(e,0,2);const d=x.getImageData(0,0,28,28).data;for(let i=0;i<d.length;i+=4)if(d[i+3]>60&&(Math.abs(d[i]-d[i+1])>24||Math.abs(d[i+1]-d[i+2])>24))return true;return false};
 if(!col('😀'))return;let mx=10;for(const[v,e]of[[11,'🥰'],[12,'🥱'],[13,'🥲'],[14,'🫠'],[15,'🫨'],[16,'🫩']]){if(col(e))mx=v;else break}EMO.max=mx;
 const W=x.measureText('😀').width||22;EMO.wide=e=>x.measureText(e).width>W*1.45}catch(e){}}
const emoFlag=e=>/^[\u{1F1E6}-\u{1F1FF}]{2}$|^\u{1F3F4}[\u{E0061}-\u{E007A}]/u.test(e);
function emoOk(e){if(EMO.bad.has(e))return false;let ok=true;const V=EMO.vmap;if(V&&V[e]&&V[e]>EMO.max)ok=false;
 else if(EMO.wide&&!emoFlag(e)&&[...e].length>1&&/‍|[\u{1F3FB}-\u{1F3FF}]|⃣/u.test(e)&&EMO.wide(e))ok=false;if(!ok)EMO.bad.add(e);return ok}
function emoIndex(){const D=EMO.data;if(EMO.flat)return;EMO.vmap={};for(const v in D.V)for(const e of D.V[v].split(' '))EMO.vmap[e]=+v;
 EMO.flat=[];D.G.forEach(g=>g[3].forEach(([,list])=>list.split(' ').forEach(s=>EMO.flat.push(s))));EMO.words=D.K.split('|')}
/* Georgian words to search by: each leads to English words of the list */
const EMOKA={'სიცილ':'laugh joy tears rolling lol','ღიმილ':'smile smiling grin','გაღიმ':'smile grin','ბედნიერ':'happy smile grin','მხიარულ':'happy joy laugh party','ცრემლ':'tear tears cry','ტირ':'cry crying sob tear',
 'სევდ':'sad pensive disappointed frown','მოწყენ':'sad pensive disappointed','ბრაზ':'angry rage pouting steam','გაბრაზ':'angry rage pouting','სიყვარ':'love heart hearts kiss','გულ':'heart','კოცნ':'kiss','ჩახუტ':'hug hugging',
 'სირცხვ':'flushed blush shy','ეჭვ':'thinking skeptical monocle raised','ფიქრ':'thinking','გაკვირვ':'surprised astonished open mouth shocked','გაოცებ':'astonished surprised shocked wow','ვაიმე':'astonished scream shocked','შიშ':'fear fearful scream anxious',
 'ძილ':'sleep sleeping sleepy zzz','ძინავ':'sleeping sleepy zzz','დაღლ':'tired weary yawning','ავად':'sick nauseated vomiting mask thermometer','ცხელ':'hot','ცივ':'cold freezing snowflake','ეშმაკ':'devil imp','ანგელოზ':'angel halo','მოჩვენებ':'ghost',
 'ჯამბაზ':'clown','რობოტ':'robot','უცხოპლანეტ':'alien','ჩონჩხ':'skull skeleton','გიჟ':'zany crazy','მაგარ':'cool sunglasses star-struck fire hundred','ასი':'hundred','ხელ':'hand','ცერ':'thumbs','მოწონ':'thumbs up like','ლაიქ':'thumbs up like heart',
 'კარგ':'thumbs ok','კაი':'thumbs ok','ცუდ':'thumbs down','ტაშ':'clap clapping','ლოცვ':'pray folded','მადლობ':'pray folded thanks','გამარჯობ':'waving wave','სალამ':'waving wave','ნახვამდის':'waving wave','ძალ':'muscle biceps flexed','კუნთ':'muscle biceps flexed',
 'მუშტ':'fist punch oncoming','გამარჯვებ':'victory trophy medal','თით':'finger index pointing','თვალ':'eye eyes','ტუჩ':'lips mouth kiss','პირ':'mouth','ფეხ':'foot leg','ბავშვ':'baby child','ბიჭ':'boy','გოგო':'girl','კაც':'man','ქალ':'woman',
 'მოხუც':'old older','ბაბუა':'old man','ბებია':'old woman','ოჯახ':'family','წყვილ':'couple','ქორწილ':'wedding bride ring couple','პოლიცი':'police','ექიმ':'health doctor','მასწავლებ':'teacher','სტუდენტ':'student graduation','მზარეულ':'cook',
 'მეხანძრ':'firefighter fire engine','ჯარისკაც':'military guard','მეფე':'king crown prince','დედოფალ':'queen crown princess','პრინცეს':'princess crown','ცეკვ':'dancing dance','სირბილ':'running runner','ცურვ':'swimming swimmer','ველოსიპედ':'bicycle bike biking',
 'ძაღლ':'dog puppy poodle','ლეკვ':'dog puppy','კატ':'cat kitten','ცხენ':'horse','ძროხ':'cow ox','ღორ':'pig','ცხვარ':'sheep ewe ram','თხა':'goat','ქათამ':'chicken hen poultry','მამალ':'rooster','წიწილ':'chick hatching','ჩიტ':'bird','არწივ':'eagle',
 'მტრედ':'dove','ბუ':'owl','დათვ':'bear','მგელ':'wolf','მელა':'fox','კურდღელ':'rabbit','თაგვ':'mouse rat','ლომ':'lion','ვეფხვ':'tiger','სპილო':'elephant','მაიმუნ':'monkey gorilla','გველ':'snake','კუ':'turtle','თევზ':'fish','ზვიგენ':'shark',
 'დელფინ':'dolphin','ვეშაპ':'whale','ფუტკარ':'bee honeybee','პეპელ':'butterfly','ობობ':'spider','ყვავილ':'flower blossom bouquet','ვარდ':'rose','ტიტ':'tulip','მზესუმზირ':'sunflower','ხე':'tree','ფოთოლ':'leaf leaves','სოკო':'mushroom',
 'კაქტუს':'cactus','ხილ':'fruit grapes apple','ყურძენ':'grapes','ვაშლ':'apple','მსხალ':'pear','ატამ':'peach','ალუბალ':'cherries','ბალ':'cherries','მარწყვ':'strawberry','საზამთრო':'watermelon','ნესვ':'melon','ლიმონ':'lemon','ფორთოხალ':'tangerine orange',
 'ბანან':'banana','ანანას':'pineapple','პომიდორ':'tomato','კიტრ':'cucumber','კარტოფილ':'potato','სტაფილო':'carrot','სიმინდ':'corn','წიწაკ':'pepper','ნიორ':'garlic','ხახვ':'onion','პურ':'bread baguette flatbread','ყველ':'cheese',
 'ხაჭაპურ':'cheese flatbread','ხინკალ':'dumpling','მწვად':'meat skewer bone poultry','ხორც':'meat cut steak bone','სუპ':'soup pot stew','სალათ':'salad','პიცა':'pizza','ბურგერ':'hamburger','ნაყინ':'ice cream','ტორტ':'cake birthday','ნამცხვარ':'cake cupcake pie cookie shortcake',
 'შოკოლად':'chocolate','კანფეტ':'candy lollipop','ტკბილ':'candy lollipop chocolate cake','თაფლ':'honey','ყავა':'coffee hot beverage','ჩაი':'teacup teapot tea','ღვინ':'wine','ლუდ':'beer mug','შამპანურ':'bottle with popping cork champagne','კოქტეილ':'cocktail tropical drink',
 'წყალ':'water droplet','რძე':'milk glass','სადღეგრძელო':'clinking glasses wine','გაუმარჯოს':'clinking glasses beer wine','სუფრა':'clinking glasses wine bread cheese','დაბადების':'birthday cake gift balloon party','გილოცავ':'party birthday gift balloon tada',
 'საჩუქარ':'gift wrapped present','ბუშტ':'balloon','ზეიმ':'party popper confetti','წვეულებ':'party popper confetti','ახალი წელ':'fireworks christmas tree sparkler','შობა':'christmas santa tree','ფეხბურთ':'soccer football ball goal','კალათბურთ':'basketball',
 'ჩოგბურთ':'tennis','რაგბ':'rugby','ჭადრაკ':'chess pawn','კარტ':'playing card joker spade suit','ჯოკერ':'joker','კამათელ':'game die','თამაშ':'game video joystick die puzzle','მედალ':'medal','თასი':'trophy','მუსიკ':'music musical notes note',
 'სიმღერ':'microphone singer musical notes','გიტარ':'guitar','დოლ':'drum','ბარაბან':'drum','ფორტეპიანო':'piano musical keyboard','ვიოლინო':'violin','ფილმ':'movie film clapper popcorn cinema','კინო':'movie film clapper popcorn cinema','ფოტო':'camera photo',
 'ტელეფონ':'mobile phone telephone','კომპიუტერ':'computer laptop desktop','წიგნ':'book books','სწავლ':'books school graduation backpack notebook pencil','სკოლ':'school backpack','გამოცდ':'memo pencil writing graduation','კალამ':'pen pencil writing',
 'ფულ':'money bag banknote coin dollar','ლარ':'money bag banknote coin','ბარათ':'credit card','საათ':'clock watch alarm','დრო':'hourglass clock stopwatch timer','კალენდარ':'calendar','სახლ':'house home','ეკლესი':'church','ტაძარ':'church',
 'მთა':'mountain snow-capped','ზღვა':'water wave beach','ტყე':'evergreen deciduous tree','ქალაქ':'cityscape city','მანქან':'automobile car','ავტობუს':'bus','მატარებელ':'train locomotive railway','თვითმფრინავ':'airplane','გემ':'ship boat',
 'მოგზაურ':'airplane luggage world map globe','ამინდ':'sun cloud rain snow','მზე':'sun sunny','მთვარ':'moon','ვარსკვლავ':'star','ღრუბელ':'cloud','წვიმ':'rain umbrella','თოვლ':'snow snowflake snowman','ელვ':'lightning voltage',
 'ქარ':'wind','ცეცხლ':'fire','ცისარტყელ':'rainbow','ფერ':'red orange yellow green blue purple','წითელ':'red','მწვანე':'green','ლურჯ':'blue','ყვითელ':'yellow','შავ':'black','თეთრ':'white','ისარ':'arrow','კითხვ':'question',
 'ძახილ':'exclamation','გაფრთხილ':'warning','სწორ':'check mark','აკრძალ':'prohibited no entry cross','დროშ':'flag','საქართველ':'georgia','ამერიკ':'united states','გერმანი':'germany','საფრანგეთ':'france','იტალი':'italy','ესპანეთ':'spain',
 'თურქეთ':'türkiye','უკრაინ':'ukraine','ინგლის':'england united kingdom','ბრიტანეთ':'united kingdom','საბერძნეთ':'greece','სომხეთ':'armenia','აზერბაიჯან':'azerbaijan','იაპონი':'japan','ჩინეთ':'china','ზოდიაქ':'aries taurus gemini cancer leo virgo libra scorpio sagittarius capricorn aquarius pisces',
 'ოქრო':'gold','გვირგვინ':'crown','ბეჭედ':'ring','ბრილიანტ':'gem diamond','ვარსკვლავებ':'star sparkles','ნიშან':'symbol sign','ბოლო':'','ცა':'sky sun cloud star moon'};
function emoSearch(q){q=String(q||'').trim().toLowerCase();if(q.length<1)return[];emoIndex();const toks=new Set();
 if(/[ა-ჿ]/.test(q)){for(const k in EMOKA)if(EMOKA[k]&&(k.startsWith(q)||k.length>=3&&q.startsWith(k)||q===k))EMOKA[k].split(' ').forEach(w=>w&&toks.add(w))}else q.split(/\s+/).forEach(w=>w&&toks.add(w));
 if(!toks.size)return[];const T=[...toks],out=[];
 EMO.flat.forEach((s,i)=>{const ws=EMO.words[i].split(' ');if(T.some(t=>ws.some(w=>t.length<3?w===t:w.startsWith(t))))out.push(s)});return out.slice(0,240)}
/* a button for each emoji that this phone can draw, in the chosen tone */
function emoBtns(list){let h='';for(const s of list){const e=emoToned(s,EMO.tone);if(!emoOk(e)){const p=emoPlain(s);if(p===e||!emoOk(p))continue;h+=`<button type="button" data-e="${p}">${p}</button>`;continue}h+=`<button type="button" data-e="${e}">${e}</button>`}return h}
const emoRecHTML=()=>'<h4>ბოლოს გამოყენებული</h4>'+(EMO.rec.length?`<div class="emog">${emoBtns(EMO.rec)}</div>`:'<p class="note emon">აქ გამოჩნდება, რასაც ხშირად იყენებ.</p>');
function emoBody(){const D=EMO.data,stk=!!(EMO.inp&&EMO.inp._stk);
 return `<section data-k="rec">${emoRecHTML()}</section>`+(stk&&typeof STICKERS!=='undefined'?`<section data-k="stk"><h4>სტიკერები</h4><div class="emost">${STICKERS.map(s=>`<button type="button" data-st="${s[0]}" aria-label="${esc(s[1])}">${stickerSVG(s[0])}</button>`).join('')}</div></section>`:'')
  +`<section data-k="ge"><h4>ჩვენებური</h4><div class="emog">${emoBtns(EMOGE.split(' '))}</div></section>`
  +D.G.map(([k,n,,subs])=>`<section data-k="${k}"><h4>${n}</h4>${subs.map(([sn,list])=>{const b=emoBtns(list.split(' '));return b?`<h5>${sn}</h5><div class="emog">${b}</div>`:''}).join('')}</section>`).join('')}
function emoTabs(){const D=EMO.data,stk=!!(EMO.inp&&EMO.inp._stk);const t=(k,i,n)=>`<button type="button" class="emot-b" data-k="${k}" role="tab" aria-label="${n}" title="${n}">${i}</button>`;
 return t('rec','🕘','ბოლოს გამოყენებული')+(stk&&typeof STICKERS!=='undefined'?t('stk','✨','სტიკერები'):'')+t('ge','🇬🇪','ჩვენებური')+D.G.map(([k,n,i])=>t(k,i,n)).join('')}
function emoPanelHTML(){return `<div class="emop" role="dialog" aria-label="სმაილები"><div class="emobar"><div class="emotabs" role="tablist">${emoTabs()}</div>
 <button type="button" class="emo-x" data-ex="find" aria-label="ძებნა">${ic('search')}</button><button type="button" class="emo-x emotn" data-ex="tone" aria-label="კანის ფერი">${emoToned('✋\u0000',EMO.tone)}</button><button type="button" class="emo-x" data-ex="del" aria-label="წაშლა">⌫</button></div>
 <div class="emotone" hidden>${EMTONE.map(t=>`<button type="button" data-tn="${t}" aria-pressed="${t===EMO.tone}">${emoToned('✋\u0000',t)}</button>`).join('')}</div>
 <div class="emofind" hidden><input type="search" class="field" placeholder="მოძებნე: გული, სიცილი, ძაღლი…" aria-label="სმაილის ძებნა" enterkeyhint="search"></div>
 <div class="emobody" tabindex="-1">${emoBody()}</div><div class="emores" hidden></div></div>`}
/* where the cursor is in the text box; an emoji goes there and the cursor after it */
function emoPut(e){const i=EMO.inp;if(!i||!i.isConnected)return;const a=i.selectionStart??i.value.length,b=i.selectionEnd??a,mx=i.maxLength>0?i.maxLength:1e9;
 if(i.value.length-(b-a)+e.length>mx){toast('ტექსტი უკვე სავსეა');return}
 try{i.setRangeText(e,a,b,'end')}catch(x){i.value=i.value.slice(0,a)+e+i.value.slice(b)}i.dispatchEvent(new Event('input',{bubbles:true}));if(matchMedia('(pointer:fine)').matches)i.focus();
 EMO.rec=[e,...EMO.rec.filter(x=>x!==e)].slice(0,40);try{store.set('emorec',EMO.rec)}catch(x){}}
function emoDel(){const i=EMO.inp;if(!i)return;let a=i.selectionStart??i.value.length,b=i.selectionEnd??a;if(a===b){if(!a)return;const before=i.value.slice(0,a);let n=1;
 try{const seg=[...new Intl.Segmenter(undefined,{granularity:'grapheme'}).segment(before)];n=seg[seg.length-1].segment.length}catch(x){const m=before.match(/(\p{Extended_Pictographic}(️|[\u{1F3FB}-\u{1F3FF}])?(‍\p{Extended_Pictographic}(️|[\u{1F3FB}-\u{1F3FF}])?)*|[\s\S])$/u);n=m?m[0].length:1}a-=n}
 i.setRangeText('',a,b,'end');i.dispatchEvent(new Event('input',{bubbles:true}))}
/* the tab of the group being looked at lights up while scrolling */
function emoSpy(){const p=EMO.p;if(!p)return;const body=$('.emobody',p),secs=$$('section',body),y=body.scrollTop+8;let k=secs[0]&&secs[0].dataset.k;for(const s of secs){if(s.offsetTop<=y)k=s.dataset.k;else break}
 $$('.emot-b',p).forEach(b=>{const on=b.dataset.k===k;b.classList.toggle('on',on);b.setAttribute('aria-selected',String(on));if(on&&EMO.spyK!==k){EMO.spyK=k;try{b.scrollIntoView({block:'nearest',inline:'nearest'})}catch(x){}}})}
function emoRedraw(){const p=EMO.p;if(!p)return;const body=$('.emobody',p),y=body.scrollTop;body.innerHTML=emoBody();body.scrollTop=y;$('.emotn',p).textContent=emoToned('✋\u0000',EMO.tone);emoSpy()}
function emoOpen(btn){const inp=document.getElementById(btn.dataset.for),host=btn.closest('.panel')||btn.closest('.view-pad')||document.body;if(!inp)return;
 emoClose(true);EMO.inp=inp;EMO.btn=btn;btn.setAttribute('aria-expanded','true');btn.classList.add('on');
 /* the phone's keyboard goes away: the panel takes its place */
 if(document.activeElement===inp&&!matchMedia('(pointer:fine)').matches)inp.blur();
 host.insertAdjacentHTML('beforeend','<div class="emop wait" role="dialog" aria-label="სმაილები"><span class="spin" aria-hidden="true"></span></div>');EMO.p=$('.emop',host);navOpen('emo');
 emoLoad().then(()=>{if(!EMO.p||!EMO.p.isConnected||EMO.inp!==inp)return;emoProbe();emoIndex();const w=document.createElement('div');w.innerHTML=emoPanelHTML();const nu=w.firstElementChild;EMO.p.replaceWith(nu);EMO.p=nu;emoWire(nu);emoSpy();
  if(!EMO.rec.length){const b=$('.emobody',nu),s=$('section[data-k="face"]',nu);if(b&&s)b.scrollTop=s.offsetTop}})
  .catch(()=>{if(EMO.p){EMO.p.classList.remove('wait');EMO.p.innerHTML='<p class="note emon">სმაილები ვერ ჩაიტვირთა. შეამოწმე ინტერნეტი და სცადე ისევ.</p>'}})}
function emoClose(nav){const p=EMO.p;EMO.p=null;if(EMO.btn){EMO.btn.setAttribute('aria-expanded','false');EMO.btn.classList.remove('on')}EMO.btn=null;if(p){p.remove();if(!nav)navKill('emo')}}
function emoWire(p){const body=$('.emobody',p),res=$('.emores',p),find=$('.emofind',p),fi=$('input',find),tone=$('.emotone',p);
 body.addEventListener('scroll',()=>{if(EMO.spyF)return;EMO.spyF=requestAnimationFrame(()=>{EMO.spyF=0;emoSpy()})},{passive:true});
 p.addEventListener('click',e=>{const b=e.target.closest('button');if(!b||!p.contains(b))return;
  if(b.dataset.e){emoPut(b.dataset.e);b.classList.remove('pop');void b.offsetWidth;b.classList.add('pop');return}
  if(b.dataset.st){const f=EMO.inp&&EMO.inp._stk,id=b.dataset.st;emoClose();if(f)f(id);return}
  if(b.dataset.k){find.hidden=true;res.hidden=true;body.hidden=false;if(b.dataset.k==='rec'){const r=$('section[data-k="rec"]',body);if(r)r.innerHTML=emoRecHTML()}const s=$(`section[data-k="${b.dataset.k}"]`,body);if(s)body.scrollTop=s.offsetTop;EMO.spyK=null;emoSpy();return}
  if(b.dataset.tn!=null){EMO.tone=b.dataset.tn;try{store.set('emotone',EMO.tone)}catch(x){}$$('[data-tn]',tone).forEach(x=>x.setAttribute('aria-pressed',String(x===b)));tone.hidden=true;emoRedraw();return}
  const x=b.dataset.ex;if(x==='del'){emoDel();return}
  if(x==='tone'){tone.hidden=!tone.hidden;return}
  if(x==='find'){const on=find.hidden;find.hidden=!on;if(on){fi.value='';res.hidden=true;body.hidden=false;fi.focus()}else{res.hidden=true;body.hidden=false}}});
 fi.addEventListener('input',()=>{const L=emoSearch(fi.value);if(!fi.value.trim()){res.hidden=true;body.hidden=false;return}body.hidden=true;res.hidden=false;
  const h=emoBtns(L);res.innerHTML=h?`<div class="emog">${h}</div>`:'<p class="note emon">ვერაფერი ვიპოვე. სცადე სხვა სიტყვა, მაგ. „გული“, „სიცილი“, „ყვავილი“.</p>'});
 fi.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();const f=$('.emores [data-e]',p);if(f)f.click()}})}
/* the panel's button: opens, or closes when open; a touch in the text box on a phone closes it (the keyboard comes instead) */
A.emo=t=>{const b=t.closest?t.closest('[data-a="emo"]')||t:t;if(EMO.p&&EMO.btn===b){emoClose();return}emoOpen(b)};
document.addEventListener('pointerdown',e=>{if(!EMO.p||!EMO.inp||e.pointerType==='mouse')return;if(e.target===EMO.inp)emoClose()},true);
/* back closes the panel, and only the panel */
{const i=OVS.findIndex(x=>x[0]==='sheet');OVS.splice(i<0?0:i,0,['emo',()=>!!EMO.p&&EMO.p.isConnected,()=>emoClose(true)])}
const emoBtnHTML=(id,o={})=>`<button type="button" class="${o.cls||'ibtn emob'}" data-a="emo" data-for="${id}" aria-label="${o.lab||'სმაილები'}" aria-expanded="false">${o.html||'😊'}</button>`;
