-- KU Smart Attendance — Supabase schema (docs/SUPABASE.md §3)
-- Paste into Supabase Dashboard → SQL Editor and run once.

create extension if not exists vector;

-- One row per student identity.
create table if not exists public.students (
  banner_id  text primary key check (banner_id ~ '^1000\d{5}$'),
  created_at timestamptz not null default now()
);

-- One row per enrollment attempt that reached upload.
create table if not exists public.enrollments (
  id           uuid primary key default gen_random_uuid(),
  banner_id    text not null references public.students on delete cascade,
  status       text not null default 'pending'
               check (status in ('pending', 'embedded', 'failed')),
  frame_count  int  not null,
  device_model text,
  created_at   timestamptz not null default now()
);

-- Only one active (non-failed) enrollment per student.
create unique index if not exists one_active_enrollment
  on public.enrollments (banner_id)
  where status <> 'failed';

-- Individual frame records pointing at Storage objects.
create table if not exists public.enrollment_frames (
  id            uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.enrollments on delete cascade,
  frame_index   int  not null,
  storage_path  text not null,
  width         int,
  height        int,
  unique (enrollment_id, frame_index)
);

-- Computed by the Python worker; consumed by the recognition system.
create table if not exists public.face_embeddings (
  id            uuid primary key default gen_random_uuid(),
  banner_id     text not null references public.students on delete cascade,
  enrollment_id uuid references public.enrollments on delete cascade,
  source_frame  uuid references public.enrollment_frames on delete set null,
  embedding     vector(512) not null,
  model         text not null default 'buffalo_l',
  created_at    timestamptz not null default now()
);

-- Similarity search index for the future recognition system.
create index if not exists face_embeddings_search
  on public.face_embeddings
  using hnsw (embedding vector_cosine_ops);

-- Lock everything down: anon/authenticated clients get nothing;
-- the Edge Function and worker use the service role, which bypasses RLS.
alter table public.students          enable row level security;
alter table public.enrollments       enable row level security;
alter table public.enrollment_frames enable row level security;
alter table public.face_embeddings   enable row level security;

-- Private bucket for enrollment frames (run once; ignore error if exists).
insert into storage.buckets (id, name, public)
values ('enrollment-frames', 'enrollment-frames', false)
on conflict (id) do nothing;
