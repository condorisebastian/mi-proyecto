-- Ejemplos exclusivamente ficticios; ejecutar explícitamente al preparar la demo.
-- No contiene credenciales. Repetirlo no modifica cuentas ni saldos existentes.
begin;
insert into operator_private.academic_registry(student_id,enrollment_id,student_card,identity_document,first_name,last_name,institution,academic_year,valid_until,active) values
 ('EST-DEMO-001','MAT-DEMO-001','CAR-DEMO-001','DEMO-1000001','Lucía','Rojas','Instituto Demo del Oriente',extract(year from current_date)::int,make_date(extract(year from current_date)::int,12,31),true),
 ('EST-DEMO-002','MAT-DEMO-002','CAR-DEMO-002','DEMO-1000002','Mateo','Vargas','Instituto Demo del Oriente',extract(year from current_date)::int,make_date(extract(year from current_date)::int,12,31),true),
 ('EST-DEMO-003','MAT-DEMO-003','CAR-DEMO-003','DEMO-1000003','Camila','Flores','Instituto Demo del Oriente',extract(year from current_date)::int-1,current_date-30,false),
 ('EST-DEMO-004','MAT-DEMO-004','CAR-DEMO-004','DEMO-1000004','Valeria','Suárez','Instituto Demo del Oriente',extract(year from current_date)::int,make_date(extract(year from current_date)::int,12,31),true)
on conflict do nothing;
insert into operator_private.customers(first_name,last_name,identity_document,birth_date,kind,requested_kind,verification,institution,student_id,enrollment_id,student_card) values
 ('Lucía','Rojas','DEMO-1000001','2005-04-12','civil','estudiante','pendiente','Instituto Demo del Oriente','EST-DEMO-001','MAT-DEMO-001','CAR-DEMO-001'),
 ('Mateo','Vargas','DEMO-1000002','2004-08-22','civil','estudiante','pendiente','Instituto Demo del Oriente','EST-DEMO-002','MAT-DEMO-002','CAR-DEMO-002'),
 ('Camila','Flores','DEMO-1000003','2003-11-02','civil','estudiante','pendiente','Instituto Demo del Oriente','EST-DEMO-003','MAT-DEMO-003','CAR-DEMO-003'),
 ('Diego','Molina','DEMO-2000001','1992-06-15','civil','civil','no_aplica',null,null,null,null),
 ('Elena','Castro','DEMO-3000001','1954-02-18','adulto_mayor','adulto_mayor','no_aplica',null,null,null,null),
 ('Andrés','Paz','DEMO-4000001','1988-09-30','discapacitado','discapacitado','no_aplica',null,null,null,null)
on conflict do nothing;
commit;
