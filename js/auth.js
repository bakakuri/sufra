/* auth: sign in, sign up, password reset, onboarding (13+, birthday) */
const CITIES=['თბილისი','ბათუმი','ქუთაისი','რუსთავი','გორი','ზუგდიდი','ფოთი','ხაშური','სამტრედია','სენაკი','ზესტაფონი','მარნეული','თელავი','ახალციხე','ქობულეთი','ოზურგეთი','კასპი','ჭიათურა','წყალტუბო','საგარეჯო','გარდაბანი','ბორჯომი','ტყიბული','ხონი','ბოლნისი','ახალქალაქი','გურჯაანი','მცხეთა','ყვარელი','ახმეტა','ლაგოდეხი','სიღნაღი','ამბროლაური','მესტია','სტეფანწმინდა'];
function authErr(e){const m=String(e?.message||e||'');
 if(/Invalid login credentials/i.test(m))return 'ელფოსტა ან პაროლი არასწორია';
 if(/Email not confirmed/i.test(m))return 'ჯერ დაადასტურე ელფოსტა. ბმული ფოსტაში გამოგიგზავნეთ';
 if(/already registered|already been registered/i.test(m))return 'ეს ელფოსტა უკვე დარეგისტრირებულია. შედი ან აღადგინე პაროლი';
 if(/Password should|at least/i.test(m))return 'პაროლი მინიმუმ 8 სიმბოლო უნდა იყოს';
 if(/rate limit|too many/i.test(m))return 'ძალიან ბევრი მცდელობა. სცადე ცოტა ხანში';
 if(/invalid.*email|Unable to validate email/i.test(m))return 'ელფოსტის მისამართი არასწორია';
 return errMsg(e)}
function authShell(inner){const el=$('#auth');el.hidden=false;const b=$('#boot');if(b)b.remove();
 el.innerHTML=`<div class="auth-in"><div class="auth-brand"><span class="logo big">სუფრა</span><p>მეგობრები, კლიპები, გაცნობა და ნარდი ერთ სუფრასთან.</p></div><div class="auth-card">${inner}</div>
 <p class="auth-foot"><button class="trb" data-a="rules">საზოგადოების წესები</button><span>·</span><button class="trb" data-a="privacy">კონფიდენციალურობა</button></p></div>`}
function showAuth(mode='in'){
 if(mode==='reset'){authShell(`<h2>პაროლის აღდგენა</h2><p class="note">შეიყვანე ელფოსტა და გამოგიგზავნით ბმულს ახალი პაროლისთვის.</p><form class="form0" id="af"><label class="fld">ელფოსტა<input id="a_e" type="email" autocomplete="email" required></label><p class="aerr" id="aerr" role="alert"></p><button class="btn wide">ბმულის გაგზავნა</button></form><button class="trb" data-a="authmode" data-m="in">შესვლაზე დაბრუნება</button>`);
  $('#af').onsubmit=async e=>{e.preventDefault();const b=$('#af button');b.disabled=true;try{const{error}=await sb.auth.resetPasswordForEmail($('#a_e').value.trim(),{redirectTo:location.origin});if(error)throw error;$('#aerr').textContent='ბმული გაიგზავნა. შეამოწმე ფოსტა, სპამის საქაღალდეც.';$('#aerr').classList.add('ok')}catch(x){$('#aerr').textContent=authErr(x)}b.disabled=false};return}
 if(mode==='newpass'){authShell(`<h2>ახალი პაროლი</h2><form class="form0" id="af"><label class="fld">ახალი პაროლი<input id="a_p" type="password" minlength="8" autocomplete="new-password" required></label><p class="aerr" id="aerr" role="alert"></p><button class="btn wide">შენახვა</button></form>`);
  $('#af').onsubmit=async e=>{e.preventDefault();try{const{error}=await sb.auth.updateUser({password:$('#a_p').value});if(error)throw error;toast('პაროლი შეიცვალა');afterLogin()}catch(x){$('#aerr').textContent=authErr(x)}};return}
 const up=mode==='up';
 authShell(`<div class="seg flat" role="tablist"><button data-a="authmode" data-m="in" aria-pressed="${!up}">შესვლა</button><button data-a="authmode" data-m="up" aria-pressed="${up}">რეგისტრაცია</button></div>
 <form class="form0" id="af">${up?'<label class="fld">სახელი და გვარი<input id="a_n" autocomplete="name" maxlength="60" required></label>':''}
 <label class="fld">ელფოსტა<input id="a_e" type="email" autocomplete="email" required></label>
 <label class="fld">პაროლი<input id="a_p" type="password" minlength="8" autocomplete="${up?'new-password':'current-password'}" required></label>
 ${up?'<label class="chk"><input type="checkbox" id="a_ok" required><span>ვეთანხმები <button type="button" class="trb" data-a="rules">წესებს</button> და <button type="button" class="trb" data-a="privacy">კონფიდენციალურობის პოლიტიკას</button>. ვარ 13 წლის ან უფროსი.</span></label>':''}
 <p class="aerr" id="aerr" role="alert"></p><button class="btn wide">${up?'ანგარიშის შექმნა':'შესვლა'}</button></form>
 ${up?'':'<button class="trb" data-a="authmode" data-m="reset">პაროლი დამავიწყდა</button>'}`);
 $('#af').onsubmit=async e=>{e.preventDefault();const b=$('#af button.btn');b.disabled=true;$('#aerr').textContent='';$('#aerr').classList.remove('ok');
  const email=$('#a_e').value.trim(),password=$('#a_p').value;
  try{if(up){const{data,error}=await sb.auth.signUp({email,password,options:{data:{name:$('#a_n').value.trim()},emailRedirectTo:location.origin}});if(error)throw error;
    if(!data.session){$('#aerr').textContent='თითქმის მზადაა! ელფოსტაზე დადასტურების ბმული გამოგიგზავნეთ. დააჭირე და შემდეგ შედი.';$('#aerr').classList.add('ok');b.disabled=false;return}}
   else{const{error}=await sb.auth.signInWithPassword({email,password});if(error)throw error}
   await afterLogin()}catch(x){$('#aerr').textContent=authErr(x);b.disabled=false}}}
A.authmode=t=>showAuth(t.dataset.m);
function showOnboarding(){
 const max=new Date();max.setFullYear(max.getFullYear()-13);const mx=max.toISOString().slice(0,10);
 authShell(`<h2>მოგესალმები სუფრაზე!</h2><p class="note">რამდენიმე დეტალი და მზად ხარ. დაბადების თარიღი სხვებს არ უჩანთ: საჭიროა ასაკის შესამოწმებლად (გაცნობა მხოლოდ 18+).</p>
 <form class="form0" id="of"><label class="fld">სახელი და გვარი<input id="o_n" maxlength="60" required value="${esc(ME.name||'')}"></label>
 <label class="fld">მომხმარებლის სახელი (არასავალდებულო)<input id="o_u" maxlength="24" pattern="[a-z0-9_.]{3,24}" placeholder="მაგ. nino.beridze" autocapitalize="none" spellcheck="false"></label>
 <label class="fld">დაბადების თარიღი<input id="o_b" type="date" max="${mx}" min="1900-01-01" required></label>
 <label class="fld">ქალაქი<input id="o_c" list="cities" maxlength="60" placeholder="მაგ. თბილისი"></label><datalist id="cities">${CITIES.map(c=>`<option value="${c}">`).join('')}</datalist>
 <p class="aerr" id="aerr" role="alert"></p><button class="btn wide">დაწყება</button></form><button class="trb" data-a="signout">სხვა ანგარიშით შესვლა</button>`);
 $('#o_u').oninput=e=>{e.target.value=e.target.value.toLowerCase().replace(/[^a-z0-9_.]/g,'')};
 $('#of').onsubmit=async e=>{e.preventDefault();const b=$('#of button.btn');b.disabled=true;
  try{await rpc('complete_onboarding',{p_name:$('#o_n').value.trim(),p_birthday:$('#o_b').value,p_username:$('#o_u').value.trim(),p_city:$('#o_c').value.trim()});ME=await rpc('my_profile');store.set('fsw',ME.id);$('#auth').hidden=true;enterApp()}
  catch(x){$('#aerr').textContent=/username|unique/i.test(x.message)?'ეს მომხმარებლის სახელი დაკავებულია':errMsg(x);b.disabled=false}}}
A.signout=async()=>{await sb.auth.signOut();location.hash='';location.reload()};
let AFTER=false;
async function afterLogin(){if(AFTER)return;AFTER=true;
 try{for(let i=0;i<4&&!ME;i++){ME=await rpc('my_profile');if(!ME)await new Promise(r=>setTimeout(r,700))}}catch(e){AFTER=false;toast(errMsg(e));showAuth('in');return}
 if(!ME){AFTER=false;showAuth('in');toast('პროფილი ვერ მოიძებნა. სცადე ხელახლა');return}
 if(!ME.onboarded){showOnboarding();return}
 $('#auth').hidden=true;$('#boot')?.remove();enterApp()}
sb.auth.onAuthStateChange((ev)=>{if(ev==='PASSWORD_RECOVERY'){AFTER=false;showAuth('newpass')}else if(ev==='SIGNED_OUT'&&ME){ME=null;location.reload()}});
async function bootAuth(){const{data:{session}}=await sb.auth.getSession();if(location.hash.includes('type=recovery'))return;if(!session){showAuth('in');return}afterLogin()}
