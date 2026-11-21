-- NovaChat cloud schema for Supabase
create extension if not exists pgcrypto;
create table if not exists public.posts (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 author_name text, text text default '', media_url text, likes integer not null default 0,
 created_at timestamptz not null default now()
);
create table if not exists public.stories (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 author_name text, media_url text not null, media_type text, caption text,
 expires_at timestamptz not null default (now()+interval '24 hours'), created_at timestamptz not null default now()
);
create table if not exists public.groups (
 id uuid primary key default gen_random_uuid(), name text not null, owner_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
create table if not exists public.group_members (
 group_id uuid not null references public.groups(id) on delete cascade, user_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(group_id,user_id)
);
create table if not exists public.communities (
 id uuid primary key default gen_random_uuid(), name text not null, description text default '',
 owner_id uuid not null references auth.users(id) on delete cascade, created_at timestamptz not null default now()
);
create table if not exists public.messages (
 id uuid primary key default gen_random_uuid(), group_id uuid not null references public.groups(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade, body text not null, created_at timestamptz not null default now()
);
alter table public.posts enable row level security;
alter table public.stories enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.communities enable row level security;
alter table public.messages enable row level security;
create policy "Authenticated users read posts" on public.posts for select to authenticated using (true);
create policy "Users create own posts" on public.posts for insert to authenticated with check (auth.uid()=user_id);
create policy "Users update own posts" on public.posts for update to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "Authenticated users read stories" on public.stories for select to authenticated using (true);
create policy "Users create own stories" on public.stories for insert to authenticated with check (auth.uid()=user_id);
create policy "Authenticated users read groups" on public.groups for select to authenticated using (true);
create policy "Users create groups" on public.groups for insert to authenticated with check (auth.uid()=owner_id);
create policy "Authenticated users read memberships" on public.group_members for select to authenticated using (true);
create policy "Users join as self" on public.group_members for insert to authenticated with check (auth.uid()=user_id);
create policy "Authenticated users read communities" on public.communities for select to authenticated using (true);
create policy "Users create communities" on public.communities for insert to authenticated with check (auth.uid()=owner_id);
create policy "Members read messages" on public.messages for select to authenticated using (exists(select 1 from public.group_members gm where gm.group_id=messages.group_id and gm.user_id=auth.uid()));
create policy "Members send messages" on public.messages for insert to authenticated with check (auth.uid()=user_id and exists(select 1 from public.group_members gm where gm.group_id=messages.group_id and gm.user_id=auth.uid()));
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('nova-media','nova-media',true,52428800,array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/quicktime','video/webm'])
on conflict (id) do update set public=true,file_size_limit=52428800;
create policy "Public read NovaChat media" on storage.objects for select using (bucket_id='nova-media');
create policy "Authenticated upload NovaChat media" on storage.objects for insert to authenticated with check (bucket_id='nova-media' and (storage.foldername(name))[2]=auth.uid()::text);
alter publication supabase_realtime add table public.posts;
alter publication supabase_realtime add table public.stories;
alter publication supabase_realtime add table public.messages;

-- Community posts and shared community feed
create table if not exists public.community_posts (
 id uuid primary key default gen_random_uuid(),
 community_id uuid not null references public.communities(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 author_name text, text text default '', media_url text,
 created_at timestamptz not null default now()
);
alter table public.community_posts enable row level security;
create policy "Authenticated users read community posts" on public.community_posts for select to authenticated using (true);
create policy "Users create own community posts" on public.community_posts for insert to authenticated with check (auth.uid()=user_id);
alter publication supabase_realtime add table public.community_posts;
