-- Create avatars bucket
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Set up access controls for avatars
create policy "Avatar images are publicly accessible."
  on storage.objects for select
  using ( bucket_id = 'avatars' );

create policy "Anyone can upload an avatar."
  on storage.objects for insert
  with check ( bucket_id = 'avatars' );

create policy "Anyone can update an avatar."
  on storage.objects for update
  with check ( bucket_id = 'avatars' );

-- Create documents bucket (for PDFs, etc)
insert into storage.buckets (id, name, public)
values ('documents', 'documents', true)
on conflict (id) do nothing;

-- Set up access controls for documents
create policy "Documents are publicly accessible."
  on storage.objects for select
  using ( bucket_id = 'documents' );

create policy "Anyone can upload a document."
  on storage.objects for insert
  with check ( bucket_id = 'documents' );

create policy "Anyone can update a document."
  on storage.objects for update
  with check ( bucket_id = 'documents' );
