-- Atención Mi Pasaje: solo puntos de demostración. Sin dinero ni cuentas bancarias.
-- Las tablas privadas no están expuestas por PostgREST. La única entrada pública
-- es una función INVOKER que delega en una función privada con control de identidad.
begin;
create schema if not exists operator_private;
revoke all on schema operator_private from public, anon, authenticated;
grant usage on schema operator_private to authenticated;

create table if not exists operator_private.operators (
  auth_id uuid primary key references auth.users(id),
  username text not null unique check (username ~ '^[a-z][a-z0-9.]{2,39}$'),
  display_name text not null check (length(display_name) between 3 and 100),
  role text not null check (role in ('operador','supervisor')),
  active boolean not null default true,
  daily_limit_cents bigint not null default 500000 check (daily_limit_cents between 50 and 5000000),
  created_at timestamptz not null default now()
);
create table if not exists operator_private.customers (
  id bigint generated always as identity (start with 100001) primary key,
  first_name text not null check (length(first_name) between 2 and 60),
  last_name text not null check (length(last_name) between 2 and 80),
  identity_document text not null unique check (identity_document ~ '^DEMO-[0-9]{7}$'),
  birth_date date not null check (birth_date between date '1900-01-01' and current_date),
  phone text not null default '' check (phone = '' or phone ~ '^[0-9+ ()-]{7,24}$'),
  kind text not null check (kind in ('civil','estudiante','adulto_mayor','discapacitado')),
  requested_kind text not null check (requested_kind in ('civil','estudiante','adulto_mayor','discapacitado')),
  status text not null default 'activo' check (status in ('activo','bloqueado')),
  verification text not null default 'no_aplica' check (verification in ('no_aplica','pendiente','aprobada','rechazada')),
  institution text, student_id text, enrollment_id text, student_card text,
  verified_until date,
  verification_revision integer not null default 1,
  balance_cents bigint not null default 0 check (balance_cents between 0 and 100000000),
  created_by uuid references operator_private.operators(auth_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint student_needs_approval check (kind <> 'estudiante' or verification = 'aprobada')
);
create table if not exists operator_private.academic_registry (
  student_id text primary key,
  enrollment_id text not null unique,
  student_card text not null unique,
  identity_document text not null unique,
  first_name text not null, last_name text not null,
  institution text not null,
  academic_year integer not null,
  valid_until date not null,
  active boolean not null default true
);
create table if not exists operator_private.evidence (
  object_id uuid primary key,
  customer_id bigint not null references operator_private.customers(id),
  kind text not null check (kind in ('carnet','matricula')),
  filename text not null check (length(filename) between 1 and 120),
  mime text not null check (mime in ('image/png','image/jpeg','application/pdf')),
  sha256 text not null check (sha256 ~ '^[a-f0-9]{64}$'),
  size_bytes integer not null check (size_bytes between 16 and 5242880),
  revision integer not null default 1,
  uploaded_by uuid not null references operator_private.operators(auth_id),
  created_at timestamptz not null default now()
);
create table if not exists operator_private.ledger (
  id bigint generated always as identity primary key,
  customer_id bigint not null references operator_private.customers(id),
  operator_id uuid not null references operator_private.operators(auth_id),
  request_id uuid not null,
  amount_cents bigint not null check (amount_cents between 50 and 100000),
  balance_after_cents bigint not null check (balance_after_cents >= 0),
  reference text not null check (length(reference) between 5 and 100),
  note text not null default '' check (length(note) <= 500),
  created_at timestamptz not null default now(),
  unique(operator_id,request_id),
  unique(reference)
);
create index if not exists ledger_customer_date on operator_private.ledger(customer_id,created_at desc);
create index if not exists ledger_operator_date on operator_private.ledger(operator_id,created_at desc);
create index if not exists customers_verification on operator_private.customers(verification,created_at);
create table if not exists operator_private.cases (
  id bigint generated always as identity primary key,
  customer_id bigint not null references operator_private.customers(id),
  subject text not null check (length(subject) between 5 and 120),
  description text not null check (length(description) between 10 and 2000),
  status text not null default 'nueva' check (status in ('nueva','en_curso','resuelta')),
  assigned_to uuid references operator_private.operators(auth_id),
  created_by uuid references operator_private.operators(auth_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists cases_status_date on operator_private.cases(status,created_at desc);
create table if not exists operator_private.audit (
  id bigint generated always as identity primary key,
  operator_id uuid references operator_private.operators(auth_id),
  customer_id bigint references operator_private.customers(id),
  action text not null,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index if not exists audit_customer_date on operator_private.audit(customer_id,created_at desc);
create index if not exists audit_date on operator_private.audit(created_at desc);
-- Conservar documentos de revisiones anteriores sin aceptarlos en una renovación.
alter table operator_private.customers add column if not exists verification_revision integer not null default 1;
alter table operator_private.evidence add column if not exists revision integer not null default 1;
alter table operator_private.evidence drop constraint if exists evidence_customer_id_kind_key;
create unique index if not exists evidence_submission_kind on operator_private.evidence(customer_id,kind,revision);

alter table operator_private.operators enable row level security;
alter table operator_private.customers enable row level security;
alter table operator_private.academic_registry enable row level security;
alter table operator_private.evidence enable row level security;
alter table operator_private.ledger enable row level security;
alter table operator_private.cases enable row level security;
alter table operator_private.audit enable row level security;
revoke all on all tables in schema operator_private from public,anon,authenticated;
revoke all on all sequences in schema operator_private from public,anon,authenticated;

create or replace function operator_private.client_json(c operator_private.customers)
returns jsonb language sql stable security invoker set search_path = '' as $$
 select to_jsonb(c) || jsonb_build_object(
   'name',c.first_name || ' ' || c.last_name,
   'effective_kind',case when c.kind='estudiante' and c.verified_until < current_date then 'civil' else c.kind end,
   'verification_display',case when c.verification='aprobada' and c.verified_until < current_date then 'vencida' else c.verification end
 );
$$;

create or replace function operator_private.registry_check(c operator_private.customers)
returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare r operator_private.academic_registry; matches boolean;
begin
 select * into r from operator_private.academic_registry where student_id=upper(trim(c.student_id));
 matches := r.student_id is not null
   and r.identity_document=c.identity_document
   and lower(trim(r.first_name))=lower(trim(c.first_name))
   and lower(trim(r.last_name))=lower(trim(c.last_name))
   and r.enrollment_id=upper(trim(c.enrollment_id))
   and r.student_card=upper(trim(c.student_card))
   and lower(trim(r.institution))=lower(trim(c.institution));
 return jsonb_build_object('matched',coalesce(matches,false),
   'active',coalesce(r.active,false),'valid_until',r.valid_until,
   'academic_year',r.academic_year,
   'eligible',coalesce(matches and r.active and r.valid_until>=current_date,false),
   'source','Padrón académico ficticio de demostración');
end;
$$;

-- SECURITY DEFINER se limita a este esquema privado y siempre comprueba auth.uid()
-- y la fila de operador activo. No confía en user_metadata ni admite SQL dinámico.
create or replace function operator_private.dispatch(p_action text,p_data jsonb default '{}')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 op operator_private.operators; customer_record operator_private.customers; ledger_record operator_private.ledger;
 result jsonb; check_result jsonb; target_id bigint; amount bigint; day_total bigint;
 reason text; target_status text; count_total bigint; case_row operator_private.cases;
 reference_text text; req uuid; existing operator_private.ledger; before_status text;
 target_operator uuid; start_day timestamptz;
begin
 if auth.uid() is null then raise exception using errcode='42501',message='Se requiere una sesión de operador.'; end if;
 select * into op from operator_private.operators where auth_id=auth.uid();
 if not found or not op.active then raise exception using errcode='42501',message='La cuenta de operador no está habilitada.'; end if;
 if jsonb_typeof(p_data)<>'object' then raise exception 'Datos inválidos.'; end if;
 start_day := (date_trunc('day',now() at time zone 'America/La_Paz') at time zone 'America/La_Paz');

 if p_action='session' then
   return jsonb_build_object('operator',to_jsonb(op),'mode','demo','currency','puntos',
     'summary',jsonb_build_object(
       'customers',(select count(*) from operator_private.customers),
       'pending',(select count(*) from operator_private.customers where verification='pendiente'),
       'blocked',(select count(*) from operator_private.customers where status='bloqueado'),
       'open_cases',(select count(*) from operator_private.cases where status<>'resuelta'),
       'my_topups_cents',(select coalesce(sum(amount_cents),0) from operator_private.ledger where operator_id=op.auth_id and created_at>=start_day)));
 elsif p_action='clients.list' then
   select count(*) into count_total from operator_private.customers x
    where (coalesce(p_data->>'q','')='' or (x.first_name || ' ' || x.last_name || ' ' || x.identity_document || ' ' || x.id::text) ilike '%' || left(p_data->>'q',100) || '%')
      and (coalesce(p_data->>'filter','')='' or x.status=p_data->>'filter' or x.verification=p_data->>'filter');
   select coalesce(jsonb_agg(row_data order by id desc),'[]') into result from (
     select x.id, jsonb_build_object('id',x.id,'name',x.first_name || ' ' || x.last_name,
       'identity_mask','DEMO-•••' || right(x.identity_document,4),'kind',x.kind,'status',x.status,
       'verification',x.verification,'balance_cents',x.balance_cents) row_data
     from operator_private.customers x
     where (coalesce(p_data->>'q','')='' or (x.first_name || ' ' || x.last_name || ' ' || x.identity_document || ' ' || x.id::text) ilike '%' || left(p_data->>'q',100) || '%')
       and (coalesce(p_data->>'filter','')='' or x.status=p_data->>'filter' or x.verification=p_data->>'filter')
     order by x.id desc limit 50 offset greatest(0,least(coalesce((p_data->>'offset')::int,0),10000))
   ) rows;
   return jsonb_build_object('items',result,'total',count_total);
 elsif p_action='clients.register' then
   if length(trim(p_data->>'first_name')) not between 2 and 60 or length(trim(p_data->>'last_name')) not between 2 and 80
      or not coalesce((p_data->>'identity_document') ~ '^DEMO-[0-9]{7}$',false)
      or coalesce(p_data->>'kind','') not in ('civil','estudiante','adulto_mayor','discapacitado')
      or coalesce(p_data->>'identity_confirmed','false')<>'true' then
     raise exception 'Revisa los nombres, el documento ficticio y la confirmación de identidad.';
   end if;
   if p_data->>'kind'='estudiante' and (
       length(trim(coalesce(p_data->>'institution','')))<3 or length(trim(coalesce(p_data->>'student_id','')))<3
       or length(trim(coalesce(p_data->>'enrollment_id','')))<3 or length(trim(coalesce(p_data->>'student_card','')))<3) then
     raise exception 'Completa la institución, matrícula, ID y carnet de estudiante.';
   end if;
   insert into operator_private.customers(first_name,last_name,identity_document,birth_date,phone,kind,requested_kind,verification,
      institution,student_id,enrollment_id,student_card,created_by)
   values(trim(p_data->>'first_name'),trim(p_data->>'last_name'),p_data->>'identity_document',(p_data->>'birth_date')::date,
      trim(coalesce(p_data->>'phone','')),case when p_data->>'kind'='estudiante' then 'civil' else p_data->>'kind' end,
      p_data->>'kind',case when p_data->>'kind'='estudiante' then 'pendiente' else 'no_aplica' end,
      trim(p_data->>'institution'),upper(trim(p_data->>'student_id')),upper(trim(p_data->>'enrollment_id')),upper(trim(p_data->>'student_card')),op.auth_id)
   returning * into customer_record;
   insert into operator_private.audit(operator_id,customer_id,action,details)
    values(op.auth_id,customer_record.id,'cliente_registrado',jsonb_build_object('categoria_solicitada',customer_record.requested_kind));
   return operator_private.client_json(customer_record);
 elsif p_action in ('clients.detail','clients.status','student.submit','student.review','evidence.add','topups.create','cases.create','demo.documents') then
   target_id := (p_data->>'customer_id')::bigint;
   -- El bloqueo del operador serializa su ledger_recordímite diario e idempotencia de recargas.
   if p_action='topups.create' then
     select * into op from operator_private.operators where auth_id=auth.uid() and active for update;
     if not found then raise exception using errcode='42501',message='Cuenta no habilitada.'; end if;
   end if;
   select * into customer_record from operator_private.customers where id=target_id for update;
   if not found then raise exception 'El cliente no existe.'; end if;

   if p_action='clients.detail' then
     return jsonb_build_object('customer',operator_private.client_json(customer_record),'registry',operator_private.registry_check(customer_record),
       'evidence',(select coalesce(jsonb_agg(to_jsonb(e) order by e.kind),'[]') from operator_private.evidence e where e.customer_id=customer_record.id and e.revision=customer_record.verification_revision),
       'movements',(select coalesce(jsonb_agg(to_jsonb(t) order by t.id desc),'[]') from (select ledger_row.*,o.display_name as operator_name from operator_private.ledger ledger_row join operator_private.operators o on o.auth_id=ledger_row.operator_id where ledger_row.customer_id=customer_record.id order by ledger_row.id desc limit 30) t),
       'audit',(select coalesce(jsonb_agg(to_jsonb(t) order by t.id desc),'[]') from (select a.*,o.display_name as operator_name from operator_private.audit a left join operator_private.operators o on o.auth_id=a.operator_id where a.customer_id=customer_record.id order by a.id desc limit 30) t));
   elsif p_action='clients.status' then
     reason := trim(coalesce(p_data->>'reason','')); target_status := p_data->>'status';
     if length(reason) not between 10 and 500 or coalesce(target_status,'') not in ('activo','bloqueado') then raise exception 'Indica el estado y un motivo de al menos 10 caracteres.'; end if;
     before_status := customer_record.status;
     update operator_private.customers set status=target_status,updated_at=now() where id=customer_record.id returning * into customer_record;
     insert into operator_private.audit(operator_id,customer_id,action,details) values(op.auth_id,customer_record.id,
       case when target_status='activo' then 'cliente_desbloqueado' else 'cliente_bloqueado' end,jsonb_build_object('motivo',reason,'antes',before_status,'despues',target_status));
     return operator_private.client_json(customer_record);
   elsif p_action='student.submit' then
     if customer_record.status<>'activo' then raise exception 'El cliente está bloqueado.'; end if;
     if length(trim(coalesce(p_data->>'institution','')))<3 or length(trim(coalesce(p_data->>'student_id','')))<3
       or length(trim(coalesce(p_data->>'enrollment_id','')))<3 or length(trim(coalesce(p_data->>'student_card','')))<3 then raise exception 'Completa los cuatro datos académicos.'; end if;
     update operator_private.customers set kind='civil',requested_kind='estudiante',verification='pendiente',verified_until=null,verification_revision=verification_revision+1,
       institution=trim(p_data->>'institution'),student_id=upper(trim(p_data->>'student_id')),
       enrollment_id=upper(trim(p_data->>'enrollment_id')),student_card=upper(trim(p_data->>'student_card')),updated_at=now()
       where id=customer_record.id returning * into customer_record;
     insert into operator_private.audit(operator_id,customer_id,action) values(op.auth_id,customer_record.id,'validacion_solicitada');
     return operator_private.client_json(customer_record);
   elsif p_action='student.review' then
     reason := trim(coalesce(p_data->>'reason',''));
     if customer_record.status<>'activo' or customer_record.verification<>'pendiente' then raise exception 'Solo se revisan solicitudes pendientes de clientes activos.'; end if;
     if length(reason) not between 10 and 500 then raise exception 'Escribe el resultado de la revisión (10 a 500 caracteres).'; end if;
     if p_data->>'decision'='aprobar' then
       check_result := operator_private.registry_check(customer_record);
       if coalesce(p_data->>'identity_reviewed','false')<>'true' or not (check_result->>'eligible')::boolean then raise exception 'No se puede aprobar: la identidad o el padrón académico no coinciden o no están vigentes.'; end if;
       if (select count(*) from operator_private.evidence where customer_id=customer_record.id and revision=customer_record.verification_revision and kind in ('carnet','matricula'))<>2 then raise exception 'Adjunta el carnet de estudiante y el comprobante de matrícula antes de aprobar.'; end if;
       update operator_private.customers set kind='estudiante',verification='aprobada',verified_until=(check_result->>'valid_until')::date,updated_at=now() where id=customer_record.id returning * into customer_record;
     elsif p_data->>'decision'='rechazar' then
       update operator_private.customers set kind='civil',verification='rechazada',verified_until=null,updated_at=now() where id=customer_record.id returning * into customer_record;
     else raise exception 'Decisión inválida.'; end if;
     insert into operator_private.audit(operator_id,customer_id,action,details) values(op.auth_id,customer_record.id,'validacion_' || customer_record.verification,jsonb_build_object('motivo',reason,'fuente','padron_ficticio','vigente_hasta',customer_record.verified_until));
     return operator_private.client_json(customer_record);
   elsif p_action='evidence.add' then
     if customer_record.status<>'activo' or customer_record.verification<>'pendiente' then raise exception 'Solo se adjuntan documentos a una validación pendiente y activa.'; end if;
     insert into operator_private.evidence(object_id,customer_id,kind,filename,mime,sha256,size_bytes,uploaded_by,revision)
     values((p_data->>'object_id')::uuid,customer_record.id,p_data->>'kind',p_data->>'filename',p_data->>'mime',p_data->>'sha256',(p_data->>'size_bytes')::int,op.auth_id,customer_record.verification_revision)
     on conflict(customer_id,kind,revision) do update set object_id=excluded.object_id,filename=excluded.filename,mime=excluded.mime,sha256=excluded.sha256,size_bytes=excluded.size_bytes,uploaded_by=excluded.uploaded_by,created_at=now();
     insert into operator_private.audit(operator_id,customer_id,action,details) values(op.auth_id,customer_record.id,'documento_adjuntado',jsonb_build_object('tipo',p_data->>'kind','sha256',p_data->>'sha256'));
     return jsonb_build_object('ok',true);
   elsif p_action='topups.create' then
     req := (p_data->>'request_id')::uuid;
     if not coalesce((p_data->>'amount') ~ '^[0-9]{1,4}([.][0-9]{1,2})?$',false) then raise exception 'El monto debe ser un número con hasta dos decimales.'; end if;
     amount := ((p_data->>'amount')::numeric * 100)::bigint;
     if amount<50 or amount>100000 or amount % 50<>0 then raise exception 'Recarga entre 0.50 y 1000 puntos, en múltiplos de 0.50.'; end if;
     reference_text := upper(trim(coalesce(p_data->>'reference','')));
     if reference_text !~ '^DEMO-[A-Z0-9-]{5,90}$' then raise exception 'La referencia ficticia debe empezar por DEMO- y ser única.'; end if;
     select * into existing from operator_private.ledger where operator_id=op.auth_id and request_id=req;
     if found then
       if existing.customer_id<>customer_record.id or existing.amount_cents<>amount or existing.reference<>reference_text then raise exception 'Esta solicitud ya se utilizó con otros datos.'; end if;
       return to_jsonb(existing) || jsonb_build_object('replayed',true,'operator_name',op.display_name);
     end if;
     if customer_record.status<>'activo' then raise exception 'No se pueden recargar puntos a un cliente bloqueado.'; end if;
     if coalesce(p_data->>'identity_confirmed','false')<>'true' or coalesce(p_data->>'identity_last4','')<>right(customer_record.identity_document,4) then raise exception 'Verifica la identidad y los últimos cuatro dígitos del documento.'; end if;
     if coalesce(p_data->>'demo_confirmed','false')<>'true' then raise exception 'Confirma que la operación utiliza puntos ficticios.'; end if;
     if length(coalesce(p_data->>'note',''))>500 then raise exception 'La observación es demasiado extensa.'; end if;
     select coalesce(sum(amount_cents),0) into day_total from operator_private.ledger where operator_id=op.auth_id and created_at>=start_day;
     if day_total+amount>op.daily_limit_cents then raise exception 'La recarga supera tu ledger_recordímite diario de demostración.'; end if;
     update operator_private.customers set balance_cents=balance_cents+amount,updated_at=now() where id=customer_record.id returning * into customer_record;
     insert into operator_private.ledger(customer_id,operator_id,request_id,amount_cents,balance_after_cents,reference,note)
     values(customer_record.id,op.auth_id,req,amount,customer_record.balance_cents,reference_text,trim(coalesce(p_data->>'note',''))) returning * into ledger_record;
     insert into operator_private.audit(operator_id,customer_id,action,details) values(op.auth_id,customer_record.id,'puntos_recargados',jsonb_build_object('comprobante',ledger_record.id,'puntos_cent',amount,'referencia',reference_text));
     return to_jsonb(ledger_record) || jsonb_build_object('replayed',false,'operator_name',op.display_name);
   elsif p_action='cases.create' then
     insert into operator_private.cases(customer_id,subject,description,assigned_to,created_by)
     values(customer_record.id,trim(p_data->>'subject'),trim(p_data->>'description'),op.auth_id,op.auth_id) returning * into case_row;
     insert into operator_private.audit(operator_id,customer_id,action,details) values(op.auth_id,customer_record.id,'atencion_abierta',jsonb_build_object('caso',case_row.id));
     return to_jsonb(case_row);
   elsif p_action='demo.documents' then
     return jsonb_build_object('customer',operator_private.client_json(customer_record),'registry',operator_private.registry_check(customer_record));
   end if;
 elsif p_action='evidence.info' then
   select to_jsonb(e) into result from operator_private.evidence e where object_id=(p_data->>'object_id')::uuid;
   if result is null then raise exception 'Documento no disponible.'; end if;
   return result;
 elsif p_action='topups.list' then
   return (select coalesce(jsonb_agg(to_jsonb(t) order by t.id desc),'[]') from (
     select l.*,c.first_name || ' ' || c.last_name as customer_name,o.display_name as operator_name
     from operator_private.ledger l join operator_private.customers c on c.id=l.customer_id join operator_private.operators o on o.auth_id=l.operator_id
     where op.role='supervisor' or l.operator_id=op.auth_id order by l.id desc limit 100) t);
 elsif p_action='cases.list' then
   return (select coalesce(jsonb_agg(to_jsonb(t) order by t.id desc),'[]') from (
     select s.*,c.first_name || ' ' || c.last_name as customer_name,o.display_name as operator_name
     from operator_private.cases s join operator_private.customers c on c.id=s.customer_id left join operator_private.operators o on o.auth_id=s.assigned_to
     order by s.id desc limit 100) t);
 elsif p_action='cases.update' then
   reason:=trim(coalesce(p_data->>'note','')); target_status:=p_data->>'status';
   if coalesce(target_status,'') not in ('nueva','en_curso','resuelta') or length(reason) not between 10 and 1000 then raise exception 'Indica un estado y una nota de atención de al menos 10 caracteres.'; end if;
   update operator_private.cases set status=target_status,assigned_to=op.auth_id,updated_at=now() where id=(p_data->>'case_id')::bigint returning * into case_row;
   if not found then raise exception 'El caso no existe.'; end if;
   insert into operator_private.audit(operator_id,customer_id,action,details) values(op.auth_id,case_row.customer_id,'atencion_actualizada',jsonb_build_object('caso',case_row.id,'estado',target_status,'nota',reason));
   return to_jsonb(case_row);
 elsif p_action='audit.list' then
   return (select coalesce(jsonb_agg(to_jsonb(t) order by t.id desc),'[]') from (
     select a.*,o.display_name as operator_name,c.first_name || ' ' || c.last_name as customer_name
     from operator_private.audit a left join operator_private.operators o on o.auth_id=a.operator_id left join operator_private.customers c on c.id=a.customer_id
     where op.role='supervisor' or a.operator_id=op.auth_id order by a.id desc limit 150) t);
 elsif p_action='registry.list' then
   return (select coalesce(jsonb_agg(to_jsonb(r) order by r.student_id),'[]') from operator_private.academic_registry r);
 elsif p_action='operators.list' then
   if op.role<>'supervisor' then raise exception using errcode='42501',message='Solo supervisión administra las cuentas de operadores.'; end if;
   return (select coalesce(jsonb_agg(to_jsonb(o) order by o.created_at),'[]') from operator_private.operators o);
 elsif p_action='operators.create' then
   if op.role<>'supervisor' then raise exception using errcode='42501',message='Solo supervisión administra las cuentas de operadores.'; end if;
   insert into operator_private.operators(auth_id,username,display_name,role)
   values((p_data->>'auth_id')::uuid,p_data->>'username',p_data->>'display_name',p_data->>'role') returning to_jsonb(operator_private.operators.*) into result;
   insert into operator_private.audit(operator_id,action,details) values(op.auth_id,'operador_creado',jsonb_build_object('usuario',p_data->>'username','rol',p_data->>'role'));
   return result;
 elsif p_action='operators.status' then
   if op.role<>'supervisor' then raise exception using errcode='42501',message='Solo supervisión administra las cuentas de operadores.'; end if;
   target_operator:=(p_data->>'auth_id')::uuid;
   if target_operator=op.auth_id then raise exception 'No puedes desactivar tu propia cuenta.'; end if;
   reason:=trim(coalesce(p_data->>'reason',''));
   if length(reason) not between 10 and 500 or jsonb_typeof(p_data->'active')<>'boolean' then raise exception 'Indica un motivo y un estado válido.'; end if;
   update operator_private.operators set active=(p_data->>'active')::boolean where auth_id=target_operator returning to_jsonb(operator_private.operators.*) into result;
   if result is null then raise exception 'La cuenta no existe.'; end if;
   insert into operator_private.audit(operator_id,action,details) values(op.auth_id,'operador_actualizado',jsonb_build_object('usuario',result->>'username','activo',p_data->'active','motivo',reason));
   return result;
 end if;
 raise exception 'Acción no disponible.';
end;
$$;

create or replace function public.operator_portal(p_action text,p_data jsonb default '{}')
returns jsonb language sql security invoker set search_path='' as $$
 select operator_private.dispatch(p_action,p_data);
$$;
revoke all on all functions in schema operator_private from public,anon,authenticated;
grant execute on function operator_private.dispatch(text,jsonb) to authenticated;
revoke all on function public.operator_portal(text,jsonb) from public,anon,authenticated;
grant execute on function public.operator_portal(text,jsonb) to authenticated;
comment on function public.operator_portal(text,jsonb) is 'Portal de atención: solo operadores activos; puntos ficticios. Tablas privadas y operaciones transaccionales.';
notify pgrst,'reload schema';
commit;
