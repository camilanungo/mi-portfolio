-- ============ PREPARACIÓN ============
drop table if exists resultados;
create temp table resultados (n int, prueba text, ok boolean, detalle text);

delete from auth.users where id in ('00000000-0000-4000-8000-0000000000a1','00000000-0000-4000-8000-0000000000a2','00000000-0000-4000-8000-0000000000a3');

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, raw_user_meta_data, raw_app_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', u.id::uuid, 'authenticated', 'authenticated', u.email, '',
       jsonb_build_object('nombre', u.nombre), '{"provider":"email","providers":["email"]}'::jsonb, now(), now()
from (values
  ('00000000-0000-4000-8000-0000000000a1', 'test-ana@ejemplo.com',   'Ana Test'),
  ('00000000-0000-4000-8000-0000000000a2', 'test-bruno@ejemplo.com', 'Bruno Test'),
  ('00000000-0000-4000-8000-0000000000a3', 'test-org@ejemplo.com',   'Org Test')
) as u(id, email, nombre);

insert into organizadores (id, usuario_id, tipo, nombre, barrio, aprobado)
values ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-0000000000a3', 'profe', 'Org Test', 'Poblenou', true);

insert into clases (id, organizador_id, titulo, tipo, profe, inicio, duracion_min, barrio, ubicacion, al_aire_libre, aforo, creditos) values
('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000b1', 'Test aire libre', 'Yoga', 'Test', now() + interval '3 days',  60, 'Poblenou', 'Test', true,  10, 3),
('00000000-0000-4000-8000-0000000000c2', '00000000-0000-4000-8000-0000000000b1', 'Test pronto',     'Yoga', 'Test', now() + interval '5 hours', 60, 'Poblenou', 'Test', false, 10, 3),
('00000000-0000-4000-8000-0000000000c3', '00000000-0000-4000-8000-0000000000b1', 'Test 1 plaza',    'Yoga', 'Test', now() + interval '2 days',  60, 'Poblenou', 'Test', false, 1,  2),
('00000000-0000-4000-8000-0000000000c4', '00000000-0000-4000-8000-0000000000b1', 'Test cara',       'Yoga', 'Test', now() + interval '2 days',  60, 'Poblenou', 'Test', false, 10, 8);

insert into movimientos (usuario_id, tipo, creditos, descripcion) values
('00000000-0000-4000-8000-0000000000a1', 'compra', 10, 'Test'),
('00000000-0000-4000-8000-0000000000a2', 'compra', 2,  'Test');

-- ============ COMO ANA ============
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', false);

do $$ declare s int; begin
  perform reservar('00000000-0000-4000-8000-0000000000c1');
  select saldo into s from saldos where usuario_id = '00000000-0000-4000-8000-0000000000a1';
  insert into resultados values (1, 'Reservar descuenta los créditos', s = 7, 'saldo: ' || s);
exception when others then insert into resultados values (1, 'Reservar descuenta los créditos', false, sqlerrm); end $$;

do $$ begin
  perform reservar('00000000-0000-4000-8000-0000000000c1');
  insert into resultados values (2, 'No se puede reservar dos veces', false, 'Dejó reservar dos veces');
exception when others then insert into resultados values (2, 'No se puede reservar dos veces', sqlerrm like '%Ya tienes plaza%', sqlerrm); end $$;

-- ============ COMO BRUNO ============
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a2","role":"authenticated"}', false);

do $$ begin
  perform reservar('00000000-0000-4000-8000-0000000000c4');
  insert into resultados values (3, 'Sin créditos no se reserva', false, 'Dejó reservar sin créditos');
exception when others then insert into resultados values (3, 'Sin créditos no se reserva', sqlerrm like '%Créditos insuficientes%', sqlerrm); end $$;

do $$ begin perform reservar('00000000-0000-4000-8000-0000000000c3'); exception when others then null; end $$;

-- ============ OTRA VEZ COMO ANA ============
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', false);

do $$ begin
  perform reservar('00000000-0000-4000-8000-0000000000c3');
  insert into resultados values (4, 'Clase completa no se reserva', false, 'Dejó reservar una clase llena');
exception when others then insert into resultados values (4, 'Clase completa no se reserva', sqlerrm like '%Clase completa%', sqlerrm); end $$;

do $$ declare r text; s int; begin
  r := cancelar_reserva((select id from reservas where clase_id = '00000000-0000-4000-8000-0000000000c1' and usuario_id = '00000000-0000-4000-8000-0000000000a1' and estado = 'activa'));
  select saldo into s from saldos where usuario_id = '00000000-0000-4000-8000-0000000000a1';
  insert into resultados values (5, 'Cancelar con más de 12 h devuelve créditos', r = 'cancelada' and s = 10, 'estado: ' || r || ', saldo: ' || s);
exception when others then insert into resultados values (5, 'Cancelar con más de 12 h devuelve créditos', false, sqlerrm); end $$;

do $$ declare r text; s int; begin
  perform reservar('00000000-0000-4000-8000-0000000000c2');
  r := cancelar_reserva((select id from reservas where clase_id = '00000000-0000-4000-8000-0000000000c2' and usuario_id = '00000000-0000-4000-8000-0000000000a1' and estado = 'activa'));
  select saldo into s from saldos where usuario_id = '00000000-0000-4000-8000-0000000000a1';
  insert into resultados values (6, 'Cancelar con menos de 12 h no devuelve', r = 'cancelada_tarde' and s = 7, 'estado: ' || r || ', saldo: ' || s);
exception when others then insert into resultados values (6, 'Cancelar con menos de 12 h no devuelve', false, sqlerrm); end $$;

do $$ begin perform reservar('00000000-0000-4000-8000-0000000000c1'); exception when others then null; end $$;

do $$ begin
  perform cancelar_por_lluvia('00000000-0000-4000-8000-0000000000c1');
  insert into resultados values (9, 'Solo el organizador cancela por lluvia', false, 'Una alumna pudo cancelar');
exception when others then insert into resultados values (9, 'Solo el organizador cancela por lluvia', sqlerrm like '%No puedes cancelar%', sqlerrm); end $$;

-- ============ COMO ORGANIZADOR ============
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a3","role":"authenticated"}', false);

do $$ declare n int; s int; begin
  n := cancelar_por_lluvia('00000000-0000-4000-8000-0000000000c1');
  select saldo into s from saldos where usuario_id = '00000000-0000-4000-8000-0000000000a1';
  insert into resultados values (7, 'Lluvia devuelve créditos a todos', n = 1 and s = 7, 'personas: ' || n || ', saldo de Ana: ' || s);
exception when others then insert into resultados values (7, 'Lluvia devuelve créditos a todos', false, sqlerrm); end $$;

do $$ begin
  perform cancelar_por_lluvia('00000000-0000-4000-8000-0000000000c2');
  insert into resultados values (8, 'Lluvia solo en clases al aire libre', false, 'Dejó cancelar una clase bajo techo');
exception when others then insert into resultados values (8, 'Lluvia solo en clases al aire libre', sqlerrm like '%al aire libre%', sqlerrm); end $$;

-- ============ SEGURIDAD: COMO ANA DESDE LA APP ============
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', false);
do $$ declare n int; begin
  select count(*) into n from reservas where usuario_id = '00000000-0000-4000-8000-0000000000a2';
  perform set_config('test.r10', case when n = 0 then 'ok' else 've ' || n || ' reservas de Bruno' end, false);
  begin
    insert into movimientos (usuario_id, tipo, creditos, descripcion) values ('00000000-0000-4000-8000-0000000000a1', 'compra', 500, 'Intento de trampa');
    perform set_config('test.r11', 'pudo regalarse 500 créditos', false);
  exception when others then perform set_config('test.r11', 'ok', false); end;
  begin
    insert into clases (organizador_id, titulo, tipo, profe, inicio, duracion_min, barrio, ubicacion, aforo, creditos)
    values ('00000000-0000-4000-8000-0000000000b1', 'Intento', 'Yoga', 'x', now() + interval '1 day', 60, 'Poblenou', 'x', 5, 1);
    perform set_config('test.r13', 'pudo publicar en un organizador ajeno', false);
  exception when others then perform set_config('test.r13', 'ok', false); end;
end $$;
reset role;

-- ============ SEGURIDAD: SIN INICIAR SESIÓN ============
set role anon;
do $$ declare v int; begin
  select libres into v from plazas_clases() where clase_id = '00000000-0000-4000-8000-0000000000c3';
  perform set_config('test.r12', coalesce(v::text, 'sin dato'), false);
exception when others then perform set_config('test.r12', 'error: ' || sqlerrm, false); end $$;
reset role;

insert into resultados values
(10, 'Una alumna no ve reservas de otros',      current_setting('test.r10') = 'ok', current_setting('test.r10')),
(11, 'Nadie puede escribir créditos a mano',    current_setting('test.r11') = 'ok', current_setting('test.r11')),
(12, 'Plazas libres visibles sin login (c3=0)', current_setting('test.r12') = '0',  'libres: ' || current_setting('test.r12')),
(13, 'No se publica en un organizador ajeno',   current_setting('test.r13') = 'ok', current_setting('test.r13'));

-- ============ LIMPIEZA Y RESULTADOS ============
delete from auth.users where id in ('00000000-0000-4000-8000-0000000000a1','00000000-0000-4000-8000-0000000000a2','00000000-0000-4000-8000-0000000000a3');

select n as "#", prueba,
       case when ok then '✅ OK' else '❌ FALLA' end as resultado,
       detalle
from resultados order by n;

-- ============ PARA GITHUB: si alguna prueba falla, marca la ejecución en rojo ============
do $$ begin
  if exists (select 1 from resultados where not ok) then
    raise exception 'Hay tests en rojo: %', (select string_agg(n || '. ' || prueba, '; ') from resultados where not ok);
  end if;
end $$;
