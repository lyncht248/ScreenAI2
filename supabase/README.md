# Supabase Backend Setup

This directory contains the Supabase backend configuration for ScreenAI.

## Setup Instructions

1. **Create a Supabase Project**
   - Go to https://supabase.com and create a new project
   - Note your project URL and anon key from Settings > API

2. **Run Migrations**
   - In Supabase Dashboard, go to SQL Editor
   - Run the migrations in `migrations/` in order:
     1. `001_create_profiles.sql`
     2. `002_create_conversations.sql`
     3. `003_create_messages.sql`
     4. `004_create_rls_policies.sql`

3. **Deploy Edge Functions**
   - Install Supabase CLI: `npm install -g supabase`
   - Login: `supabase login`
   - Link project: `supabase link --project-ref YOUR_PROJECT_REF`
   - Deploy: `supabase functions deploy openai-chat`

4. **Set Environment Variables**
   - In Supabase Dashboard, go to Project Settings > Edge Functions
   - Add secret: `OPENAI_API_KEY` with your OpenAI API key

5. **Update iOS App**
   - Add your Supabase URL and anon key to `AppConfig.swift` or `Secrets.xcconfig`

