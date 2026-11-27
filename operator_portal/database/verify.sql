-- Pruebas de autorización y reglas de negocio. Todo se revierte al terminar.
begin;
do $$
declare
  ana uuid; supervisor uuid; luis uuid; c jsonb; result jsonb; request_id uuid;
  client_id bigint; denied boolean; test_ci text; test_student text; test_enrollment text; test_card text; last4 text; wrong_last4 text; spent bigint;
begin
  select auth_id into ana from operator_private.operators where username='ana.atencion';
  select auth_id into supervisor from operator_private.operators where username='supervisor.demo';
  select auth_id into luis from operator_private.operators where username='luis.atencion';
  if ana is null or supervisor is null or luis is null then raise exception 'Faltan las cuentas de demostración.'; end if;
  if has_function_privilege('anon','public.operator_portal(text,jsonb)','execute') then raise exception 'Anon puede ejecutar el portal.'; end if;
  if has_table_privilege('authenticated','operator_private.customers','select') or has_table_privilege('anon','operator_private.operators','select') then raise exception 'Tablas privadas expuestas.'; end if;
  loop
    test_ci:='DEMO-' || (7000000+floor(random()*999999))::int::text;
    exit when not exists(select 1 from operator_private.customers where identity_document=test_ci)
      and not exists(select 1 from operator_private.academic_registry where identity_document=test_ci);
  end loop;
  test_student:='EST-TEST-' || upper(gen_random_uuid()::text);
  test_enrollment:='MAT-TEST-' || upper(gen_random_uuid()::text);
  test_card:='CAR-TEST-' || upper(gen_random_uuid()::text);
  last4:=right(test_ci,4);wrong_last4:=case when last4='9999' then '0000' else '9999' end;
  insert into operator_private.academic_registry(student_id,enrollment_id,student_card,identity_document,first_name,last_name,institution,academic_year,valid_until)
  values(test_student,test_enrollment,test_card,test_ci,'Estudiante','Prueba Temporal','Instituto de Pruebas',extract(year from current_date)::int,current_date+90);
  select coalesce(sum(amount_cents),0) into spent from operator_private.ledger where operator_id=ana
    and created_at>=(date_trunc('day',now() at time zone 'America/La_Paz') at time zone 'America/La_Paz');
  update operator_private.operators set daily_limit_cents=spent+1000 where auth_id=ana;
  perform set_config('request.jwt.claim.sub',ana::text,true);
  execute 'set local role authenticated';
  result:=public.operator_portal('session');
  if result->'operator'->>'username'<>'ana.atencion' then raise exception 'Identidad de operador incorrecta.'; end if;
  denied:=false;
  begin perform public.operator_portal('operators.list'); exception when insufficient_privilege then denied:=true; end;
  if not denied then raise exception 'Un operador administra otras cuentas.'; end if;
  c:=public.operator_portal('clients.register',jsonb_build_object('first_name','Estudiante','last_name','Prueba Temporal','identity_document',test_ci,
    'birth_date','2005-02-05','kind','estudiante','institution','Instituto de Pruebas','student_id',test_student,
    'enrollment_id',test_enrollment,'student_card',test_card,'identity_confirmed',true));
  client_id:=(c->>'id')::bigint;
  if c->>'kind'<>'civil' or c->>'verification'<>'pendiente' or (c->>'balance_cents')::bigint<>0 then raise exception 'Estudiante no verificado obtuvo beneficios o saldo.'; end if;
  denied:=false;
  begin perform public.operator_portal('student.review',jsonb_build_object('customer_id',client_id,'decision','aprobar','identity_reviewed',true,'reason','Revisión de prueba completa.')); exception when raise_exception then denied:=true; end;
  if not denied then raise exception 'Se aprobó sin documentos.'; end if;
  perform public.operator_portal('evidence.add',jsonb_build_object('customer_id',client_id,'object_id',gen_random_uuid(),'kind','carnet','filename','ficticio.pdf','mime','application/pdf','sha256',repeat('a',64),'size_bytes',100));
  perform public.operator_portal('evidence.add',jsonb_build_object('customer_id',client_id,'object_id',gen_random_uuid(),'kind','matricula','filename','ficticio.pdf','mime','application/pdf','sha256',repeat('b',64),'size_bytes',100));
  denied:=false;
  begin perform public.operator_portal('student.review',jsonb_build_object('customer_id',client_id,'decision','aprobar','identity_reviewed',false,'reason','Revisión de prueba completa.')); exception when raise_exception then denied:=true; end;
  if not denied then raise exception 'Se aprobó sin revisión de identidad.'; end if;
  result:=public.operator_portal('student.review',jsonb_build_object('customer_id',client_id,'decision','aprobar','identity_reviewed',true,'reason','Padrón y documentos ficticios revisados.'));
  if result->>'kind'<>'estudiante' or result->>'verification'<>'aprobada' then raise exception 'No se aprobó la validación correcta.'; end if;
  perform public.operator_portal('student.submit',jsonb_build_object('customer_id',client_id,'institution','Instituto de Pruebas','student_id',test_student,'enrollment_id',test_enrollment,'student_card',test_card));
  result:=public.operator_portal('clients.detail',jsonb_build_object('customer_id',client_id));
  if jsonb_array_length(result->'evidence')<>0 then raise exception 'Una renovación reutilizó documentos anteriores.'; end if;
  request_id:=gen_random_uuid();
  result:=public.operator_portal('topups.create',jsonb_build_object('customer_id',client_id,'request_id',request_id,'amount','0.50','reference','DEMO-TEST-'||request_id,'identity_last4',last4,'identity_confirmed',true,'demo_confirmed',true));
  if (result->>'amount_cents')::bigint<>50 or (result->>'balance_after_cents')::bigint<>50 then raise exception 'Error de centavos.'; end if;
  result:=public.operator_portal('topups.create',jsonb_build_object('customer_id',client_id,'request_id',request_id,'amount','0.50','reference','DEMO-TEST-'||request_id,'identity_last4',last4,'identity_confirmed',true,'demo_confirmed',true));
  if not (result->>'replayed')::boolean then raise exception 'No se reconoció el reintento.'; end if;
  result:=public.operator_portal('clients.detail',jsonb_build_object('customer_id',client_id));
  if (result->'customer'->>'balance_cents')::bigint<>50 or jsonb_array_length(result->'movements')<>1 then raise exception 'Recarga duplicada.'; end if;
  denied:=false;
  begin perform public.operator_portal('topups.create',jsonb_build_object('customer_id',client_id,'request_id',gen_random_uuid(),'amount','0.50','reference','DEMO-TEST-'||request_id,'identity_last4',last4,'identity_confirmed',true,'demo_confirmed',true)); exception when unique_violation then denied:=true; end;
  if not denied then raise exception 'Se aceptó una referencia repetida.'; end if;
  denied:=false;
  begin perform public.operator_portal('topups.create',jsonb_build_object('customer_id',client_id,'request_id',gen_random_uuid(),'amount','0.51','reference','DEMO-TEST-INVALID','identity_last4',last4,'identity_confirmed',true,'demo_confirmed',true)); exception when raise_exception then denied:=true; end;
  if not denied then raise exception 'Se aceptó un incremento distinto de 0.50.'; end if;
  denied:=false;
  begin perform public.operator_portal('topups.create',jsonb_build_object('customer_id',client_id,'request_id',gen_random_uuid(),'amount','0.50','reference','DEMO-TEST-IDENTITY','identity_last4',wrong_last4,'identity_confirmed',true,'demo_confirmed',true)); exception when raise_exception then denied:=true; end;
  if not denied then raise exception 'No se comprobó el documento.'; end if;
  denied:=false;
  begin perform public.operator_portal('topups.create',jsonb_build_object('customer_id',client_id,'request_id',gen_random_uuid(),'amount','10.00','reference','DEMO-TEST-LIMIT','identity_last4',last4,'identity_confirmed',true,'demo_confirmed',true)); exception when raise_exception then denied:=true; end;
  if not denied then raise exception 'No se aplicó el límite diario.'; end if;
  perform public.operator_portal('clients.status',jsonb_build_object('customer_id',client_id,'status','bloqueado','reason','Bloqueo ficticio para comprobar la restricción.'));
  denied:=false;
  begin perform public.operator_portal('topups.create',jsonb_build_object('customer_id',client_id,'request_id',gen_random_uuid(),'amount','0.50','reference','DEMO-TEST-BLOCK','identity_last4',last4,'identity_confirmed',true,'demo_confirmed',true)); exception when raise_exception then denied:=true; end;
  if not denied then raise exception 'Cliente bloqueado recibió puntos.'; end if;
  result:=public.operator_portal('clients.detail',jsonb_build_object('customer_id',client_id));
  if (result->'customer'->>'balance_cents')::bigint<>50 then raise exception 'Una operación rechazada cambió el saldo.'; end if;
  perform set_config('request.jwt.claim.sub',supervisor::text,true);
  perform public.operator_portal('operators.status',jsonb_build_object('auth_id',luis,'active',false,'reason','Desactivación ficticia para comprobar la sesión.'));
  perform set_config('request.jwt.claim.sub',luis::text,true);
  denied:=false;
  begin perform public.operator_portal('session'); exception when insufficient_privilege then denied:=true; end;
  if not denied then raise exception 'Una cuenta desactivada conserva el acceso.'; end if;
  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  denied:=false;
  begin perform public.operator_portal('clients.list'); exception when insufficient_privilege then denied:=true; end;
  if not denied then raise exception 'Un usuario ajeno accedió al portal.'; end if;
  execute 'reset role';
  raise notice 'Autorización, validación estudiantil, renovación, centavos, identidad, idempotencia, límites, bloqueo y revocación: aprobados.';
end;
$$;
rollback;
