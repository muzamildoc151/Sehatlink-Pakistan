-- SEHATLINK V4 DATABASE
-- DEMO/STARTER ONLY. Do not use the demo directory as real doctor listings.
-- Run in Supabase SQL Editor after creating your project.
--
-- SECURITY MODEL:
-- * Patient case data is private.
-- * Payment receipt metadata is private.
-- * Doctor access is restricted by doctor_roles.
-- * Specialist directory is public only for verified=true records.
-- * Receipt files should live in a PRIVATE Supabase Storage bucket.
--
-- NEVER place a Supabase secret/service-role key in GitHub/browser code.

create extension if not exists pgcrypto;

create table if not exists public.doctor_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  doctor_name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.cases (
  id uuid primary key default gen_random_uuid(),
  case_code text unique not null default ('SL-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
  name text not null,
  age int check (age between 0 and 120),
  gender text,
  phone text,
  city text not null,
  problem text not null,
  duration text,
  severity text,
  symptoms text,
  conditions text,
  medicines text,
  tests text,
  status text not null default 'payment_pending'
    check (status in ('payment_pending','paid_new','review','follow_up','referral_ready','closed')),
  assigned_doctor_id uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null unique references public.cases(id) on delete cascade,
  amount_pkr integer not null default 200 check (amount_pkr > 0),
  method text not null default 'JazzCash',
  sender_name text,
  sender_phone text,
  transaction_reference text,
  receipt_path text,
  status text not null default 'pending'
    check (status in ('pending','approved','rejected')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.specialists (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  specialty text not null,
  city text not null,
  clinic_name text,
  phone text,
  verified boolean not null default false,
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.doctor_roles enable row level security;
alter table public.cases enable row level security;
alter table public.payments enable row level security;
alter table public.specialists enable row level security;

revoke all on public.cases from anon;
revoke all on public.payments from anon;
revoke all on public.doctor_roles from anon;

create policy "active doctors can read cases"
on public.cases for select to authenticated
using (
  exists(select 1 from public.doctor_roles d
         where d.user_id=auth.uid() and d.active=true)
  and (assigned_doctor_id=auth.uid() or assigned_doctor_id is null)
);

create policy "assigned doctors can update cases"
on public.cases for update to authenticated
using (
  exists(select 1 from public.doctor_roles d
         where d.user_id=auth.uid() and d.active=true)
  and assigned_doctor_id=auth.uid()
)
with check (assigned_doctor_id=auth.uid());

create policy "active doctors can read payments"
on public.payments for select to authenticated
using (
  exists(select 1 from public.doctor_roles d
         where d.user_id=auth.uid() and d.active=true)
);

create policy "active doctors can update payments"
on public.payments for update to authenticated
using (
  exists(select 1 from public.doctor_roles d
         where d.user_id=auth.uid() and d.active=true)
)
with check (
  exists(select 1 from public.doctor_roles d
         where d.user_id=auth.uid() and d.active=true)
);

create policy "public sees only verified real specialists"
on public.specialists for select to anon, authenticated
using (verified=true and is_demo=false);

-- Patient creation function. Returns ONLY the case code.
create or replace function public.create_patient_case(
  p_name text,p_age int,p_gender text,p_location text,p_phone text,
  p_problem text,p_duration text,p_severity text,p_symptoms text default null,
  p_conditions text default null,p_medicines text default null,p_tests text default null
) returns text
language plpgsql security definer set search_path=public
as $$
declare new_id uuid; new_code text;
begin
  if length(trim(p_name)) < 2 then raise exception 'Invalid name'; end if;
  if length(trim(p_problem)) < 3 then raise exception 'Please describe the problem'; end if;
  if length(trim(p_location)) < 2 then raise exception 'Invalid location'; end if;
  insert into public.cases(name,age,gender,phone,city,problem,duration,severity,symptoms,conditions,medicines,tests)
  values(trim(p_name),p_age,p_gender,p_phone,trim(p_location),trim(p_problem),
         p_duration,p_severity,p_symptoms,p_conditions,p_medicines,p_tests)
  returning id,case_code into new_id,new_code;
  insert into public.payments(case_id,amount_pkr,method) values(new_id,200,'JazzCash');
  return new_code;
end;
$$;

revoke all on function public.create_patient_case(text,int,text,text,text,text,text,text,text,text,text,text) from public;
grant execute on function public.create_patient_case(text,int,text,text,text,text,text,text,text,text,text,text) to anon, authenticated;

-- Demo consultants: intentionally fictional and NOT advertised as real doctors.
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 001','Internal Medicine','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 002','Cardiology','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 003','Dermatology','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 004','ENT','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 005','Gastroenterology','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 006','Orthopedics','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 007','Gynecology','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 008','Pediatrics','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 009','Neurology','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 010','Psychiatry','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 011','Ophthalmology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 012','Urology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 013','Nephrology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 014','Pulmonology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 015','Endocrinology','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 016','General Surgery','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 017','Neurosurgery','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 018','Rheumatology','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 019','Hematology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 020','Oncology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 021','Internal Medicine','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 022','Cardiology','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 023','Dermatology','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 024','ENT','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 025','Gastroenterology','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 026','Orthopedics','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 027','Gynecology','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 028','Pediatrics','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 029','Neurology','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 030','Psychiatry','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 031','Ophthalmology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 032','Urology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 033','Nephrology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 034','Pulmonology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 035','Endocrinology','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 036','General Surgery','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 037','Neurosurgery','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 038','Rheumatology','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 039','Hematology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 040','Oncology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 041','Internal Medicine','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 042','Cardiology','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 043','Dermatology','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 044','ENT','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 045','Gastroenterology','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 046','Orthopedics','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 047','Gynecology','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 048','Pediatrics','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 049','Neurology','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 050','Psychiatry','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 051','Ophthalmology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 052','Urology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 053','Nephrology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 054','Pulmonology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 055','Endocrinology','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 056','General Surgery','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 057','Neurosurgery','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 058','Rheumatology','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 059','Hematology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 060','Oncology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 061','Internal Medicine','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 062','Cardiology','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 063','Dermatology','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 064','ENT','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 065','Gastroenterology','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 066','Orthopedics','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 067','Gynecology','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 068','Pediatrics','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 069','Neurology','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 070','Psychiatry','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 071','Ophthalmology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 072','Urology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 073','Nephrology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 074','Pulmonology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 075','Endocrinology','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 076','General Surgery','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 077','Neurosurgery','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 078','Rheumatology','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 079','Hematology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 080','Oncology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 081','Internal Medicine','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 082','Cardiology','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 083','Dermatology','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 084','ENT','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 085','Gastroenterology','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 086','Orthopedics','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 087','Gynecology','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 088','Pediatrics','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 089','Neurology','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 090','Psychiatry','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 091','Ophthalmology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 092','Urology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 093','Nephrology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 094','Pulmonology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 095','Endocrinology','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 096','General Surgery','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 097','Neurosurgery','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 098','Rheumatology','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 099','Hematology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 100','Oncology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 101','Internal Medicine','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 102','Cardiology','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 103','Dermatology','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 104','ENT','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 105','Gastroenterology','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 106','Orthopedics','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 107','Gynecology','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 108','Pediatrics','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 109','Neurology','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 110','Psychiatry','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 111','Ophthalmology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 112','Urology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 113','Nephrology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 114','Pulmonology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 115','Endocrinology','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 116','General Surgery','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 117','Neurosurgery','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 118','Rheumatology','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 119','Hematology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 120','Oncology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 121','Internal Medicine','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 122','Cardiology','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 123','Dermatology','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 124','ENT','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 125','Gastroenterology','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 126','Orthopedics','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 127','Gynecology','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 128','Pediatrics','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 129','Neurology','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 130','Psychiatry','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 131','Ophthalmology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 132','Urology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 133','Nephrology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 134','Pulmonology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 135','Endocrinology','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 136','General Surgery','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 137','Neurosurgery','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 138','Rheumatology','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 139','Hematology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 140','Oncology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 141','Internal Medicine','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 142','Cardiology','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 143','Dermatology','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 144','ENT','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 145','Gastroenterology','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 146','Orthopedics','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 147','Gynecology','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 148','Pediatrics','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 149','Neurology','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 150','Psychiatry','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 151','Ophthalmology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 152','Urology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 153','Nephrology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 154','Pulmonology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 155','Endocrinology','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 156','General Surgery','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 157','Neurosurgery','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 158','Rheumatology','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 159','Hematology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 160','Oncology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 161','Internal Medicine','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 162','Cardiology','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 163','Dermatology','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 164','ENT','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 165','Gastroenterology','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 166','Orthopedics','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 167','Gynecology','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 168','Pediatrics','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 169','Neurology','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 170','Psychiatry','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 171','Ophthalmology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 172','Urology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 173','Nephrology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 174','Pulmonology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 175','Endocrinology','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 176','General Surgery','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 177','Neurosurgery','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 178','Rheumatology','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 179','Hematology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 180','Oncology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 181','Internal Medicine','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 182','Cardiology','Lahore','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 183','Dermatology','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 184','ENT','Multan','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 185','Gastroenterology','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 186','Orthopedics','Islamabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 187','Gynecology','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 188','Pediatrics','Rawalpindi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 189','Neurology','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 190','Psychiatry','Karachi','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 191','Ophthalmology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 192','Urology','Faisalabad','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 193','Nephrology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 194','Pulmonology','Peshawar','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 195','Endocrinology','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 196','General Surgery','Quetta','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 197','Neurosurgery','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 198','Rheumatology','Sialkot','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 199','Hematology','Bahawalpur','DEMO — Not a real clinic',null,false,true);
insert into public.specialists(name,specialty,city,clinic_name,phone,verified,is_demo) values ('Demo Consultant 200','Oncology','Bahawalpur','DEMO — Not a real clinic',null,false,true);

-- IMPORTANT: Do NOT insert real doctor records until you verify identity,
-- registration, specialty, clinic and contact information.
