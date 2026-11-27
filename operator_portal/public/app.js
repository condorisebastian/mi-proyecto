const $=(selector,root=document)=>root.querySelector(selector);
const esc=value=>String(value??'').replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const icon=name=>`<svg class="icon" aria-hidden="true"><use href="#${name}"/></svg>`;
const format=value=>new Intl.NumberFormat('es-BO',{minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(value||0)/100);
const date=value=>value?new Intl.DateTimeFormat('es-BO',{dateStyle:'medium',timeStyle:'short'}).format(new Date(value)):'—';
const labels={civil:'Civil',estudiante:'Estudiante',adulto_mayor:'Adulto mayor',discapacitado:'Persona con discapacidad',activo:'Activo',bloqueado:'Bloqueado',pendiente:'Pendiente',aprobada:'Aprobada',rechazada:'Rechazada',vencida:'Vencida',no_aplica:'No requiere',nueva:'Nueva',en_curso:'En curso',resuelta:'Resuelta'};
const actions={cliente_registrado:'Cliente registrado',cliente_bloqueado:'Cliente bloqueado',cliente_desbloqueado:'Cliente desbloqueado',validacion_solicitada:'Validación solicitada',validacion_aprobada:'Estudiante aprobado',validacion_rechazada:'Validación rechazada',documento_adjuntado:'Documento adjuntado',puntos_recargados:'Puntos recargados',atencion_abierta:'Caso abierto',atencion_actualizada:'Atención actualizada',operador_creado:'Operador creado',operador_actualizado:'Cuenta de operador actualizada'};
const badge=(value,label=labels[value]||value)=>`<span class="badge ${['activo','aprobada','resuelta'].includes(value)?'green':['bloqueado','rechazada','vencida'].includes(value)?'red':value==='pendiente'||value==='nueva'?'orange':''}">${esc(label)}</span>`;
const initials=name=>String(name||'').split(/\s+/).slice(0,2).map(s=>s[0]||'').join('');
const empty=(message='No hay registros para mostrar.')=>`<div class="empty-state">${esc(message)}</div>`;
const state={session:null,csrf:null,view:'clientes',selected:null,detail:null,tab:'ficha',q:'',filter:'',offset:0,clients:[],total:0,requestId:null,epoch:0};
let toastTimer,searchTimer;
const topupKey=()=>`mi-pasaje.topup.${state.session.operator.auth_id}.${state.selected}`;
function topupRequest(){
  let value;try{value=sessionStorage.getItem(topupKey());}catch{}
  if(!value||!/^[a-f0-9-]{36}$/.test(value)){value=crypto.randomUUID();try{sessionStorage.setItem(topupKey(),value);}catch{}}
  return value;
}

function toast(message,error=false) { const element=$('#toast');element.textContent=message;element.classList.toggle('error-toast',error);element.hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>element.hidden=true,error?10000:5000); }
function closeModal(){const dialog=$('#modal');if(dialog.open)dialog.close();$('#modal-body').replaceChildren();}
function showLogin(message='') { closeModal();state.session=null;state.csrf=null;state.detail=null;state.clients=[];$('#workspace').hidden=true;$('#login').hidden=false;$('.skip').href='#login-main';$('#password').value='';$('#main').innerHTML='';$('#login-error').hidden=!message;$('#login-error').textContent=message; }
async function api(path,{method='GET',data,body,headers={}}={}) {
  const response=await fetch('/api'+path,{method,credentials:'same-origin',headers:{...(data?{'Content-Type':'application/json'}:{}),...(method==='POST'?{'X-CSRF-Token':state.csrf||''}:{}),...headers},body:data?JSON.stringify(data):body});
  const result=await response.json();
  if(!response.ok) { if(response.status===401 && path!=='/login') showLogin('Tu sesión terminó. Vuelve a ingresar.');throw new Error(result.error||'No se pudo completar la operación.'); }
  return result;
}
function updateSession(session) {
  state.session=session;state.csrf=session.csrf;
  $('#login').hidden=true;$('#workspace').hidden=false;$('.skip').href='#main';
  $('#operator-name').textContent=session.operator.display_name;
  $('#operator-role').textContent=session.operator.role==='supervisor'?'Supervisión':'Operador de atención';
  $('#operator-avatar').textContent=initials(session.operator.display_name);
  $('#operators-nav').hidden=session.operator.role!=='supervisor';
  $('#pending-count').textContent=session.summary.pending||'';
}
async function refreshSession() {updateSession(await api('/session'));}
function heading(title,description,action='') {return `<div class="page-heading"><div><h1>${esc(title)}</h1><p>${esc(description)}</p></div>${action}</div>`;}
function registerButton(){return `<button class="button primary" data-action="register">${icon('plus')}Registrar cliente</button>`;}
function summary(){const s=state.session.summary;return `<div class="summary-strip"><div><strong>${s.customers}</strong>clientes</div><div><strong>${s.pending}</strong>validaciones pendientes</div><div><strong>${format(s.my_topups_cents)}</strong>puntos recargados por ti hoy</div></div>`;}

async function navigate(view) {
  if(!['clientes','validaciones','recargas','atencion','historial','operadores'].includes(view)) view='clientes';
  if(view==='operadores' && state.session.operator.role!=='supervisor') return;
  state.view=view;const epoch=++state.epoch;
  for(const button of document.querySelectorAll('[data-view]')) button.setAttribute('aria-current',button.dataset.view===view?'page':'false');
  $('#main').innerHTML='<div class="loading" role="status">Consultando los registros…</div>';
  try {
    if(view==='clientes'||view==='validaciones') {
      if(view==='validaciones') {state.filter='pendiente';state.offset=0;}
      $('#main').innerHTML=heading(view==='validaciones'?'Validaciones estudiantiles':'¿A quién atendemos?',view==='validaciones'?'Revisa el padrón, el carnet y la matrícula antes de aprobar la categoría.':'Encuentra al cliente por nombre, documento ficticio o número de registro.',registerButton())+summary()+
        `<div class="workspace-grid"><section class="client-list-panel" aria-label="Buscar clientes"><div class="list-tools"><label for="customer-search">Buscar cliente</label><div class="search-wrap">${icon('search')}<input id="customer-search" type="search" value="${esc(state.q)}" placeholder="Nombre, DEMO-… o registro" autocomplete="off" maxlength="100"></div><label class="field-hint" for="client-filter">Estado de la atención</label><select id="client-filter"><option value="">Todos los clientes</option><option value="pendiente">Validación pendiente</option><option value="bloqueado">Bloqueados</option><option value="activo">Activos</option></select><p id="results-info" class="results-info" role="status"></p></div><div id="customer-list" class="customer-list"></div><div id="pagination"></div></section><section id="detail" aria-label="Ficha del cliente">${detailEmpty()}</section></div>`;
      $('#client-filter').value=state.filter;
      await loadClients(epoch);
      if(state.selected && epoch===state.epoch) await selectCustomer(state.selected,false);
    } else if(view==='recargas') {
      const rows=await api('/topups');if(epoch!==state.epoch)return;
      state.movements=rows;
      $('#main').innerHTML=heading('Recargas de puntos','Cada recarga tiene un cliente, una referencia única y un operador responsable.',`<button class="button primary" data-action="go-recharge">${icon('plus')}Nueva recarga</button>`)+summary()+table(['Comprobante','Cliente','Puntos','Operador','Fecha',''],rows.map(r=>`<tr><td><strong>MP-${String(r.id).padStart(6,'0')}</strong><small>${esc(r.reference)}</small></td><td>${esc(r.customer_name)}</td><td class="positive">+${format(r.amount_cents)}</td><td>${esc(r.operator_name)}</td><td>${date(r.created_at)}</td><td><button class="button" data-action="receipt" data-id="${r.id}">Ver comprobante</button></td></tr>`),'Todavía no hay recargas. Busca un cliente para cargar sus primeros puntos.');
    } else if(view==='atencion') {
      const rows=await api('/cases');if(epoch!==state.epoch)return;state.cases=rows;
      $('#main').innerHTML=heading('Casos de atención','Consulta los casos abiertos y deja una nota al continuar o resolver una atención.',`<button class="button primary" data-action="new-case">${icon('plus')}Abrir un caso</button>`)+table(['Caso','Cliente','Estado','Responsable','Actualizado',''],rows.map(r=>`<tr><td><strong>#${r.id} ${esc(r.subject)}</strong><small>${esc(r.description).slice(0,150)}</small></td><td>${esc(r.customer_name)}</td><td>${badge(r.status)}</td><td>${esc(r.operator_name||'Sin asignar')}</td><td>${date(r.updated_at)}</td><td><button class="button" data-action="case-update" data-id="${r.id}">Atender</button></td></tr>`),'No hay casos pendientes de atención.');
    } else if(view==='historial') {
      const rows=await api('/audit');if(epoch!==state.epoch)return;
      $('#main').innerHTML=heading('Registro de acciones',state.session.operator.role==='supervisor'?'Consulta qué cambió, quién lo hizo y cuándo.':'Aquí se registran las operaciones realizadas con tu cuenta.')+table(['Acción','Cliente','Operador','Detalle','Fecha'],rows.map(r=>`<tr><td><strong>${esc(actions[r.action]||r.action)}</strong></td><td>${esc(r.customer_name||'—')}</td><td>${esc(r.operator_name||'Preparación de demo')}</td><td>${auditDescription(r.details)}</td><td>${date(r.created_at)}</td></tr>`));
    } else if(view==='operadores') {
      const rows=await api('/operators');if(epoch!==state.epoch)return;state.operators=rows;
      $('#main').innerHTML=heading('Cada atención, con su responsable','Crea cuentas individuales y desactiva el acceso cuando un operador deje de atender.',`<button class="button primary" data-action="operator-create">${icon('plus')}Crear operador</button>`)+table(['Operador','Usuario','Rol','Límite diario','Estado',''],rows.map(r=>`<tr><td><strong>${esc(r.display_name)}</strong></td><td>${esc(r.username)}</td><td>${r.role==='supervisor'?'Supervisión':'Operador'}</td><td>${format(r.daily_limit_cents)} puntos</td><td>${badge(r.active?'activo':'bloqueado',r.active?'Habilitado':'Desactivado')}</td><td>${r.auth_id===state.session.operator.auth_id?'<span class="muted">Tu cuenta</span>':`<button class="button" data-action="operator-status" data-id="${esc(r.auth_id)}">${r.active?'Desactivar':'Habilitar'}</button>`}</td></tr>`));
    }
  } catch(error) {if(epoch===state.epoch && state.session)$('#main').innerHTML=heading('No pudimos cargar este apartado',error.message,`<button class="button" data-action="retry">Reintentar</button>`);}
}
function table(headers,rows,message){return rows.length?`<div class="table-wrap"><table><thead><tr>${headers.map(h=>`<th scope="col">${esc(h||'Acción')}</th>`).join('')}</tr></thead><tbody>${rows.join('')}</tbody></table></div>`:empty(message);}
function detailEmpty(){return `<div class="detail-empty">${icon('card')}<h2>Una buena atención comienza aquí.</h2><p>Selecciona un cliente para consultar su ficha, recargar puntos o revisar sus documentos.</p></div>`;}
async function loadClients(epoch=state.epoch){
  const q=state.q,filter=state.filter,offset=state.offset;
  const data=await api('/clients?'+new URLSearchParams({q,filter,offset}));
  if(epoch!==state.epoch||q!==state.q||filter!==state.filter||offset!==state.offset)return;
  state.clients=data.items;state.total=data.total;
  $('#results-info').textContent=`${data.total} ${data.total===1?'cliente encontrado':'clientes encontrados'}`;
  $('#customer-list').innerHTML=data.items.length?data.items.map(c=>`<button class="customer-row" data-action="select-customer" data-id="${c.id}" aria-current="${state.selected===c.id}"><span class="avatar">${esc(initials(c.name))}</span><span class="row-text"><strong>${esc(c.name)}</strong><small>${esc(c.identity_mask)}</small>${c.status==='bloqueado'?badge(c.status):c.verification==='pendiente'?badge('pendiente','Validar estudiante'):badge(c.kind,labels[c.kind])}</span><span class="row-balance">${format(c.balance_cents)}<small>puntos</small></span></button>`).join(''):empty('No se encontró el cliente. Revisa la búsqueda o registra uno nuevo.');
  $('#pagination').innerHTML=data.total>50?`<div class="form-actions"><button class="button" data-action="previous-page" ${offset===0?'disabled':''}>Anterior</button><button class="button" data-action="next-page" ${offset+50>=data.total?'disabled':''}>Siguiente</button></div>`:'';
}
async function selectCustomer(id,resetTab=true){
  state.selected=Number(id);state.requestId=null;if(resetTab)state.tab=state.view==='validaciones'?'validacion':'ficha';
  const selected=state.selected;
  $('#detail').innerHTML='<div class="loading" role="status">Abriendo la ficha…</div>';
  try {const data=await api(`/clients/${selected}`);if(state.selected!==selected||!$('#detail'))return;state.detail=data;renderDetail();document.querySelectorAll('.customer-row').forEach(row=>row.setAttribute('aria-current',Number(row.dataset.id)===selected?'true':'false'));}
  catch(error){if($('#detail'))$('#detail').innerHTML=`<p class="error">${esc(error.message)}</p>`;}
}
function renderDetail(){
  const d=state.detail,c=d.customer;
  $('#detail').innerHTML=`<article class="panel"><div class="detail-header"><div class="detail-person"><span class="avatar">${esc(initials(c.name))}</span><div><h2>${esc(c.name)}</h2><p>Registro ${c.id} · ${esc(c.identity_document)}</p></div><button class="button ${c.status==='activo'?'danger':''}" data-action="customer-status">${icon('lock')}${c.status==='activo'?'Bloquear':'Desbloquear'}</button></div><div class="badges">${badge(c.status)}${badge(c.effective_kind,labels[c.effective_kind])}${c.requested_kind==='estudiante'?badge(c.verification_display,'Estudiante: '+labels[c.verification_display]):''}</div></div><div class="balance-line"><span>Su billetera de demostración</span><strong>${format(c.balance_cents)} <small>puntos</small></strong></div><div class="detail-tabs" role="tablist" aria-label="Atender al cliente">${[['ficha','Ficha'],['recargar','Recargar'],['validacion','Validación'],['caso','Atención'],['movimientos','Movimientos']].map(([key,label])=>`<button role="tab" aria-selected="${state.tab===key}" data-action="detail-tab" data-tab="${key}">${label}</button>`).join('')}</div><div class="detail-body" role="tabpanel">${detailContent()}</div></article>`;
}
function detailContent(){
  const d=state.detail,c=d.customer;
  if(state.tab==='ficha')return `<h3>Datos del cliente</h3><dl class="definition-grid"><div><dt>Nombre completo</dt><dd>${esc(c.name)}</dd></div><div><dt>Documento ficticio</dt><dd>${esc(c.identity_document)}</dd></div><div><dt>Fecha de nacimiento</dt><dd>${esc(c.birth_date)}</dd></div><div><dt>Teléfono de referencia</dt><dd>${esc(c.phone||'Sin registrar')}</dd></div><div><dt>Categoría solicitada</dt><dd>${esc(labels[c.requested_kind])}</dd></div><div><dt>Registro</dt><dd>${date(c.created_at)}</dd></div></dl>${c.verification==='pendiente'?'<div class="note warning">La categoría estudiantil está pendiente. El cliente mantiene la categoría Civil hasta completar la revisión.</div>':''}<div class="section-divider"></div><h3>Últimas acciones</h3>${auditList(d.audit)}`;
  if(state.tab==='recargar') {
    if(c.status!=='activo')return `<div class="note warning">Este cliente está bloqueado. Revisa el motivo antes de habilitarlo; no se permiten recargas.</div>`;
    state.requestId??=topupRequest();
    return `<h3>Recargar puntos ficticios</h3><p class="muted">Confirma los datos con el cliente antes de registrar la recarga.</p><form id="topup-form"><div class="field-grid"><label>Puntos a recargar<input name="amount" id="topup-amount" inputmode="decimal" placeholder="0.50" required pattern="[0-9]{1,4}([.,][0-9]{1,2})?"><span class="field-hint">De 0.50 a 1000 puntos. Incrementos de 0.50.</span></label><label>Últimos 4 dígitos del documento<input name="identity_last4" inputmode="numeric" pattern="[0-9]{4}" minlength="4" maxlength="4" required autocomplete="off"></label><label class="span-two">Referencia ficticia de la recarga<input name="reference" required pattern="DEMO-(?:[A-Za-z0-9]|-){5,90}" maxlength="95" value="DEMO-${state.requestId.slice(0,8).toUpperCase()}"><span class="field-hint">Una referencia distinta para cada recarga.</span></label><label class="span-two">Observación (opcional)<textarea name="note" maxlength="500" rows="2" placeholder="Detalle útil para esta atención"></textarea></label></div><div class="quick-amounts" aria-label="Montos frecuentes">${[5,10,20,50,100].map(n=>`<button type="button" data-action="amount" data-amount="${n}">${n}</button>`).join('')}</div><label class="check-label"><input type="checkbox" name="identity_confirmed" required>Contrasté el nombre y documento con el cliente.</label><label class="check-label"><input type="checkbox" name="demo_confirmed" required>Esta operación utiliza puntos ficticios, sin recibir ni mover dinero real.</label><div class="form-actions"><button class="button primary" type="submit">${icon('wallet')}Confirmar recarga</button></div></form>`;
  }
  if(state.tab==='validacion')return validationContent(d);
  if(state.tab==='caso')return `<h3>Registrar una atención</h3><p class="muted">Deja un caso para dar seguimiento a la consulta del cliente.</p><form id="case-form"><label>Asunto<input name="subject" required minlength="5" maxlength="120" placeholder="Por ejemplo: revisión de una recarga"></label><label>Detalle de la consulta<textarea name="description" required minlength="10" maxlength="2000" rows="4"></textarea></label><div class="form-actions"><button type="submit" class="button primary">Abrir caso de atención</button></div></form>`;
  if(state.tab==='movimientos')return `<h3>Recargas de este cliente</h3>${table(['Comprobante','Puntos','Fecha',''],d.movements.map(r=>`<tr><td><strong>MP-${String(r.id).padStart(6,'0')}</strong><small>${esc(r.reference)}</small></td><td class="positive">+${format(r.amount_cents)}</td><td>${date(r.created_at)}</td><td><button class="button" data-action="receipt" data-id="${r.id}">Ver</button></td></tr>`),'El cliente todavía no tiene recargas.')}<div class="section-divider"></div><h3>Historial de atención</h3>${auditList(d.audit)}`;
  return '';
}
function validationContent(d){
  const c=d.customer,r=d.registry;
  if(c.requested_kind!=='estudiante'||['rechazada','vencida'].includes(c.verification_display))return `<h3>${c.requested_kind==='estudiante'?'Renovar la validación':'Solicitar categoría estudiantil'}</h3><p class="muted">Adjunta datos de una matrícula vigente para iniciar la revisión. La categoría será Civil hasta su aprobación.</p><form id="student-form">${studentFields(c)}<div class="form-actions"><button type="submit" class="button primary">Enviar a validación</button></div></form><div class="note">Solo se contrasta con el padrón ficticio de esta demo. Una revisión real requiere a la institución educativa.</div>`;
  const documents=d.evidence;
  const ready=r.eligible&&documents.length===2&&c.status==='activo';
  return `<h3>Revisión estudiantil</h3><dl class="definition-grid"><div><dt>Institución</dt><dd>${esc(c.institution)}</dd></div><div><dt>ID de estudiante</dt><dd>${esc(c.student_id)}</dd></div><div><dt>Matrícula</dt><dd>${esc(c.enrollment_id)}</dd></div><div><dt>Carnet estudiantil</dt><dd>${esc(c.student_card)}</dd></div></dl><div class="note ${r.eligible?'success':'warning'}"><strong>${r.eligible?'Los datos coinciden y la matrícula está vigente.':r.matched?'El registro académico está inactivo o vencido.':'Los datos no coinciden con el padrón académico.'}</strong><br>Padrón ficticio de demostración${r.valid_until?'. Vigente hasta '+esc(r.valid_until):''}. No constituye una validación oficial.</div><div class="proof-list">${['carnet','matricula'].map(kind=>{const e=documents.find(x=>x.kind===kind);return `<div class="proof">${icon('file')}<div class="proof-text"><strong>${kind==='carnet'?'Carnet de estudiante':'Comprobante de matrícula'}</strong><small>${e?esc(e.filename):'Documento pendiente'}</small></div>${e?`<a href="/api/evidence/${esc(e.object_id)}" download>Descargar</a>`:''}${c.verification==='pendiente'&&c.status==='activo'?`<label class="file-button">${e?'Reemplazar':'Adjuntar'}<input type="file" data-evidence="${kind}" accept="image/png,image/jpeg,application/pdf" aria-label="Adjuntar ${kind==='carnet'?'carnet de estudiante':'comprobante de matrícula'}"></label>`:''}</div>`;}).join('')}</div>${c.verification==='pendiente'&&c.status==='activo'?`<p class="field-hint">PNG, JPG o PDF. Máximo 5 MB por documento.</p>${r.matched?'<button class="inline-link" data-action="demo-documents">Cargar documentos ficticios para esta prueba</button>':''}<div class="section-divider"></div><form id="review-form"><label>Resultado de la revisión<select name="decision" id="review-decision"><option value="aprobar" ${!ready?'disabled':''}>Aprobar categoría estudiantil</option><option value="rechazar" ${!ready?'selected':''}>Rechazar solicitud</option></select></label>${!ready?'<p class="field-hint">Para aprobar deben coincidir los datos, estar vigente la matrícula y adjuntarse ambos documentos.</p>':''}<label class="check-label"><input type="checkbox" name="identity_reviewed">Revisé los documentos y contrasté el nombre, la fotografía y la identidad del cliente.</label><label>Motivo o resultado de la revisión<textarea name="reason" required minlength="10" maxlength="500" rows="3"></textarea></label><div class="form-actions"><button class="button primary" type="submit">Guardar revisión</button></div></form>`:`<div class="note success">Categoría estudiantil ${esc(labels[c.verification_display]?.toLowerCase())}${c.verified_until?' hasta '+esc(c.verified_until):''}. La revisión quedó registrada con su operador responsable.</div>`}`;
}
function studentFields(c={}){return `<div class="field-grid"><label class="span-two">Institución educativa<input name="institution" required minlength="3" maxlength="120" value="${esc(c.institution||'Instituto Demo del Oriente')}"></label><label>ID de estudiante<input name="student_id" required minlength="3" maxlength="60" value="${esc(c.student_id||'')}" placeholder="EST-DEMO-…"></label><label>Número de matrícula<input name="enrollment_id" required minlength="3" maxlength="60" value="${esc(c.enrollment_id||'')}" placeholder="MAT-DEMO-…"></label><label class="span-two">Número de carnet estudiantil<input name="student_card" required minlength="3" maxlength="60" value="${esc(c.student_card||'')}" placeholder="CAR-DEMO-…"></label></div>`;}
function auditDescription(details={}){return esc(details.motivo||details.nota||(details.puntos_cent?format(details.puntos_cent)+' puntos · '+details.referencia:details.categoria_solicitada?labels[details.categoria_solicitada]:details.tipo?details.tipo==='carnet'?'Carnet estudiantil':'Matrícula':details.usuario?details.usuario:details.caso?'Caso #'+details.caso:'—'));}
function auditList(rows){return rows.length?rows.map(r=>`<div class="audit-item">${icon(r.action.includes('recarg')?'wallet':r.action.includes('validacion')?'shield':'history')}<div><strong>${esc(actions[r.action]||r.action)}</strong><p>${auditDescription(r.details)}</p><small>${esc(r.operator_name||'Preparación de demo')} · ${date(r.created_at)}</small></div></div>`).join(''):empty('Todavía no hay acciones para este cliente.');}

function openModal(title,subtitle,content){$('#modal-body').innerHTML=`<div class="modal-header"><div><h2 id="modal-title">${esc(title)}</h2>${subtitle?`<p>${esc(subtitle)}</p>`:''}</div><button class="icon-button" data-action="close-modal" aria-label="Cerrar">${icon('close')}</button></div><div class="modal-content">${content}</div>`;$('#modal').showModal();}
const modalActions=label=>`<p id="form-error" class="error" role="alert" hidden></p><div class="form-actions"><button class="button" type="button" data-action="close-modal">Cancelar</button><button class="button primary" type="submit">${esc(label)}</button></div>`;
async function showRegister(){
  openModal('Registrar un cliente','Datos ficticios para probar Mi Pasaje Atención.',`<form id="register-form"><div class="field-grid"><label>Nombres<input name="first_name" required minlength="2" maxlength="60" autocomplete="off"></label><label>Apellidos<input name="last_name" required minlength="2" maxlength="80" autocomplete="off"></label><label>Documento ficticio<input name="identity_document" required pattern="DEMO-[0-9]{7}" placeholder="DEMO-1234567" maxlength="12"><span class="field-hint">Usa DEMO- seguido de 7 números.</span></label><label>Fecha de nacimiento<input name="birth_date" type="date" min="1900-01-01" max="${new Date().toISOString().slice(0,10)}" required></label><label>Teléfono ficticio (opcional)<input name="phone" maxlength="24" inputmode="tel" autocomplete="off"></label><label>Categoría solicitada<select name="kind" id="registration-kind">${Object.entries(labels).filter(([k])=>['civil','estudiante','adulto_mayor','discapacitado'].includes(k)).map(([k,v])=>`<option value="${k}">${v}</option>`).join('')}</select></label></div><fieldset id="academic-fields" hidden><legend>Datos académicos</legend>${studentFields()}<div class="note warning">El registro queda pendiente. La categoría estudiantil exige documentos, matrícula vigente y revisión del operador.</div></fieldset><label class="check-label"><input type="checkbox" name="identity_confirmed" required>Revisé los datos de identidad de este cliente ficticio.</label>${modalActions('Registrar cliente')}</form>`);
  for(const field of $('#academic-fields').querySelectorAll('input'))field.required=false;
}
function showReceipt(movement){
  const name=movement.customer_name||state.detail?.customer.name||'';
  openModal('Comprobante de recarga','Operación de demostración, sin valor monetario.',`<div class="receipt"><h3>Mi Pasaje · Puntos ficticios</h3>${badge('aprobada','Recarga registrada')}<div class="receipt-total">+${format(movement.amount_cents)} puntos</div><dl><div><dt>Comprobante</dt><dd>MP-${String(movement.id).padStart(6,'0')}</dd></div><div><dt>Fecha</dt><dd>${date(movement.created_at)}</dd></div><div><dt>Cliente</dt><dd>${esc(name)}</dd></div><div><dt>Operador</dt><dd>${esc(movement.operator_name)}</dd></div><div><dt>Referencia</dt><dd>${esc(movement.reference)}</dd></div><div><dt>Saldo después de la operación</dt><dd>${format(movement.balance_after_cents)} puntos</dd></div>${movement.note?`<div><dt>Observación</dt><dd>${esc(movement.note)}</dd></div>`:''}</dl><div class="note">Este comprobante registra puntos ficticios. No certifica una transferencia, depósito o pago bancario.</div></div><div class="form-actions"><button class="button" data-action="close-modal">Cerrar</button><button class="button primary" data-action="print-receipt">Imprimir comprobante</button></div>`);
}
async function afterMutation(message){await refreshSession();if($('#modal').open)closeModal();if(['clientes','validaciones'].includes(state.view)){await loadClients();if(state.selected)await selectCustomer(state.selected,false);}else await navigate(state.view);toast(message);}
async function busy(form,task){const buttons=[...form.querySelectorAll('button')];buttons.forEach(b=>b.disabled=true);const errorBox=$('#form-error',form);if(errorBox)errorBox.hidden=true;try{await task();}catch(error){if(errorBox&&errorBox.isConnected){errorBox.hidden=false;errorBox.textContent=error.message;}else toast(error.message,true);}finally{buttons.forEach(b=>b.disabled=false);}}
function inputData(form){const data=Object.fromEntries(new FormData(form));for(const [key,value] of Object.entries(data))if(typeof value==='string')data[key]=value.trim();for(const key of ['identity_confirmed','identity_reviewed','demo_confirmed'])data[key]=data[key]==='on';return data;}

document.addEventListener('submit',event=>{
  const form=event.target;if(!(form instanceof HTMLFormElement))return;event.preventDefault();
  const data=inputData(form);
  if(form.id==='login-form')return busy(form,async()=>{try{updateSession(await api('/login',{method:'POST',data:{username:data.username,password:$('#password').value}}));$('#password').value='';await navigate('clientes');}catch(error){$('#login-error').hidden=false;$('#login-error').textContent=error.message;}});
  busy(form,async()=>{
    if(form.id==='register-form'){const c=await api('/clients',{method:'POST',data});state.selected=c.id;state.tab=c.requested_kind==='estudiante'?'validacion':'ficha';await refreshSession();closeModal();state.filter='';state.q='';await navigate('clientes');toast('Cliente registrado. Su saldo inicial es 0 puntos.');}
    if(form.id==='topup-form'){const customerId=state.selected,customerName=state.detail.customer.name,requestKey=topupKey();data.amount=data.amount.replace(',','.');data.request_id=state.requestId;const result=await api(`/clients/${customerId}/topups`,{method:'POST',data});try{sessionStorage.removeItem(requestKey);}catch{}if(state.selected===customerId)state.requestId=null;await afterMutation(result.replayed?'La recarga anterior ya estaba registrada. No se duplicó.':'Recarga registrada correctamente.');showReceipt({...result,customer_name:customerName});}
    if(form.id==='status-form'){await api(`/clients/${state.selected}/status`,{method:'POST',data:{reason:data.reason,status:state.detail.customer.status==='activo'?'bloqueado':'activo'}});await afterMutation('Estado del cliente actualizado.');}
    if(form.id==='student-form'){await api(`/clients/${state.selected}/student`,{method:'POST',data});await afterMutation('Validación enviada a revisión.');}
    if(form.id==='review-form'){if(data.decision==='aprobar'&&!data.identity_reviewed)throw new Error('Confirma la revisión de identidad antes de aprobar.');await api(`/clients/${state.selected}/review`,{method:'POST',data});await afterMutation('Revisión estudiantil registrada.');}
    if(form.id==='case-form'){await api(`/clients/${state.selected}/cases`,{method:'POST',data});await afterMutation('Caso de atención abierto.');}
    if(form.id==='case-update-form'){await api('/cases/'+form.dataset.id,{method:'POST',data});await afterMutation('Seguimiento del caso actualizado.');}
    if(form.id==='operator-create-form'){const result=await api('/operators',{method:'POST',data});closeModal();await navigate('operadores');openModal('Cuenta creada',result.notice,`<p>Usuario: <strong>${esc(result.operator.username)}</strong></p><label>Clave de acceso<output class="credential">${esc(result.password)}</output></label><p class="muted">Entrégala únicamente a ${esc(result.operator.display_name)}. No se guardará en el navegador.</p><div class="form-actions"><button class="button primary" data-action="close-modal">He entregado la clave</button></div>`);}
    if(form.id==='operator-status-form'){await api('/operators/status',{method:'POST',data:{...data,auth_id:form.dataset.id,active:form.dataset.active==='true'}});await afterMutation('Acceso del operador actualizado.');}
  });
});
document.addEventListener('click',async event=>{
  const nav=event.target.closest('[data-view]');if(nav&&state.session)return navigate(nav.dataset.view);
  const button=event.target.closest('[data-action]');if(!button)return;
  const action=button.dataset.action;
  try {
    if(action==='close-modal')return closeModal();
    if(action==='register')return showRegister();
    if(action==='retry')return navigate(state.view);
    if(action==='select-customer')return selectCustomer(button.dataset.id);
    if(action==='detail-tab'){state.tab=button.dataset.tab;renderDetail();}
    if(action==='amount')$('#topup-amount').value=Number(button.dataset.amount).toFixed(2);
    if(action==='next-page'||action==='previous-page'){state.offset+=action==='next-page'?50:-50;await loadClients();}
    if(action==='customer-status')openModal(state.detail.customer.status==='activo'?'Bloquear cliente':'Desbloquear cliente',state.detail.customer.name,`<form id="status-form"><p>La decisión y tu nombre quedarán registrados en el historial de atención.</p><label>Motivo<textarea name="reason" required minlength="10" maxlength="500" rows="3"></textarea></label>${modalActions('Guardar estado')}</form>`);
    if(action==='demo-documents'){button.disabled=true;try{await api(`/clients/${state.selected}/demo-documents`,{method:'POST',data:{}});await afterMutation('Se adjuntaron dos documentos ficticios, sin validez oficial.');}finally{button.disabled=false;}}
    if(action==='receipt'){const movement=[...(state.movements||[]),...(state.detail?.movements||[])].find(r=>r.id===Number(button.dataset.id));if(movement)showReceipt(movement);}
    if(action==='print-receipt')window.print();
    if(action==='go-recharge'||action==='new-case'){state.tab=action==='go-recharge'?'recargar':'caso';await navigate('clientes');if(state.selected)renderDetail();else toast('Selecciona al cliente que vas a atender.');}
    if(action==='case-update'){const c=state.cases.find(c=>c.id===Number(button.dataset.id));openModal('Atender caso #'+c.id,c.customer_name,`<p><strong>${esc(c.subject)}</strong></p><p>${esc(c.description)}</p><form id="case-update-form" data-id="${c.id}"><label>Estado<select name="status">${['nueva','en_curso','resuelta'].map(v=>`<option value="${v}" ${c.status===v?'selected':''}>${labels[v]}</option>`).join('')}</select></label><label>Nota de seguimiento<textarea name="note" required minlength="10" maxlength="1000" rows="3"></textarea></label>${modalActions('Guardar seguimiento')}</form>`);}
    if(action==='operator-create')openModal('Crear cuenta de operador','Cada cuenta tiene su propia clave y registro de acciones.',`<form id="operator-create-form"><label>Nombre del responsable<input name="display_name" minlength="3" maxlength="100" required autocomplete="off"></label><label>Usuario<input name="username" pattern="[a-z][a-z0-9.]{2,39}" required maxlength="40" autocapitalize="none" autocomplete="off"><span class="field-hint">Letras minúsculas, números y puntos. Por ejemplo: maria.atencion.</span></label><label>Rol<select name="role"><option value="operador">Operador</option><option value="supervisor">Supervisión</option></select></label><div class="note">Se generará una clave única que se mostrará una sola vez. El operador no comparte la cuenta de supervisión.</div>${modalActions('Crear cuenta')}</form>`);
    if(action==='operator-status'){const o=state.operators.find(o=>o.auth_id===button.dataset.id);openModal(o.active?'Desactivar acceso':'Habilitar acceso',o.display_name,`<form id="operator-status-form" data-id="${esc(o.auth_id)}" data-active="${!o.active}"><label>Motivo<textarea name="reason" minlength="10" maxlength="500" rows="3" required></textarea></label>${modalActions('Guardar acceso')}</form>`);}
  } catch(error){toast(error.message,true);}
});
document.addEventListener('input',event=>{if(event.target.id==='customer-search'){state.q=event.target.value;state.offset=0;clearTimeout(searchTimer);searchTimer=setTimeout(()=>loadClients().catch(error=>toast(error.message,true)),250);}});
document.addEventListener('change',async event=>{
  const field=event.target;
  if(field.id==='client-filter'){state.filter=field.value;state.offset=0;await loadClients().catch(error=>toast(error.message,true));}
  if(field.id==='registration-kind'){const show=field.value==='estudiante';$('#academic-fields').hidden=!show;for(const input of $('#academic-fields').querySelectorAll('input'))input.required=show;}
  if(field.dataset.evidence&&field.files?.[0]){
    const file=field.files[0];if(file.size>5*1024*1024){toast('El archivo supera 5 MB.',true);field.value='';return;}
    field.disabled=true;
    try{await api(`/clients/${state.selected}/evidence?kind=${field.dataset.evidence}`,{method:'POST',body:file,headers:{'Content-Type':file.type,'X-File-Name':file.name.replace(/[^a-zA-Z0-9._ -]/g,'_')}});await afterMutation('Documento adjuntado para su revisión.');}catch(error){toast(error.message,true);field.disabled=false;}
  }
});
$('#logout').addEventListener('click',async()=>{try{await api('/logout',{method:'POST',data:{}});}catch{}finally{showLogin();$('#username').focus();}});
$('#modal').addEventListener('close',()=>{if(!$('#modal').open)$('#modal-body').replaceChildren();});
$('#modal').addEventListener('cancel',event=>{event.preventDefault();closeModal();});
document.addEventListener('keydown',event=>{
  const tab=event.target.closest('[role="tab"]');if(!tab||!['ArrowLeft','ArrowRight','Home','End'].includes(event.key))return;
  event.preventDefault();const tabs=[...document.querySelectorAll('[role="tab"]')],index=tabs.indexOf(tab);
  const next=event.key==='Home'?tabs[0]:event.key==='End'?tabs.at(-1):tabs[(index+(event.key==='ArrowRight'?1:tabs.length-1))%tabs.length];
  const name=next.dataset.tab;next.click();document.querySelector(`[data-tab="${name}"]`)?.focus();
});
try {updateSession(await api('/session'));await navigate('clientes');}catch{showLogin();}
