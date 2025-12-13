# Supabase Backend Setup Guide

This guide will walk you through setting up the Supabase backend for ScreenAI.

## Prerequisites

1. A Supabase account (sign up at https://supabase.com)
2. Supabase CLI installed: `npm install -g supabase`
3. Xcode with your iOS project open

## Step 1: Create Supabase Project

1. Go to https://supabase.com and create a new project
2. Note your project details:
   - **Project URL**: Found in Settings > API > Project URL
   - **Anon Key**: Found in Settings > API > Project API keys > `anon` `public`

## Step 2: Run Database Migrations

1. Open your Supabase Dashboard
2. Go to **SQL Editor**
3. Run each migration file in order from `supabase/migrations/`:
   - `001_create_profiles.sql`
   - `002_create_conversations.sql`
   - `003_create_messages.sql`
   - `004_create_rls_policies.sql`

Alternatively, if you have Supabase CLI linked:
```bash
supabase db push
```

## Step 3: Deploy Edge Function

1. Install Supabase CLI (if not already installed):
   ```bash
   npm install -g supabase
   ```

2. Login to Supabase:
   ```bash
   supabase login
   ```

3. Link your project (replace `YOUR_PROJECT_REF` with your project reference ID):
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   ```

4. Set your OpenAI API key as a secret:
   ```bash
   supabase secrets set OPENAI_API_KEY=your_openai_api_key_here
   ```

5. Deploy the Edge Function:
   ```bash
   supabase functions deploy openai-chat
   ```

## Step 4: Add Supabase Swift SDK to Xcode

1. In Xcode, select your project in the navigator
2. Select your target (ScreenAI)
3. Go to **General** tab
4. Scroll down to **Frameworks, Libraries, and Embedded Content**
5. Click the **+** button
6. Click **Add Package...**
7. Enter this URL: `https://github.com/supabase/supabase-swift`
8. Select version **2.0.0** or later
9. Click **Add Package**
10. Select the following products:
    - `Supabase`
11. Click **Add Package**

## Step 5: Configure iOS App

1. Open `ScreenAI/Info.plist` in Xcode
2. Add two new keys:
   - **SUPABASE_URL**: Your Supabase project URL
   - **SUPABASE_ANON_KEY**: Your Supabase anon key

Alternatively, if you're using `Secrets.xcconfig`:
1. Open `Secrets.xcconfig` (or create it)
2. Add:
   ```
   SUPABASE_URL = your_project_url_here
   SUPABASE_ANON_KEY = your_anon_key_here
   ```
3. Make sure `Secrets.xcconfig` is added to `.gitignore`

## Step 6: Verify Setup

1. Build and run the app in Xcode
2. You should see the authentication screen
3. Create a new account or sign in
4. The app should load your chat interface

## Troubleshooting

### Edge Function Not Working
- Verify the function is deployed: `supabase functions list`
- Check function logs: `supabase functions logs openai-chat`
- Ensure `OPENAI_API_KEY` secret is set: `supabase secrets list`

### Database Errors
- Verify RLS policies are created: Check Supabase Dashboard > Authentication > Policies
- Ensure migrations ran successfully: Check Supabase Dashboard > Database > Migrations

### Authentication Issues
- Check that email confirmation is disabled (for development) in Supabase Dashboard > Authentication > Settings
- Verify your Supabase URL and anon key are correct in Info.plist

### SDK Import Errors
- Ensure Supabase package is properly added to your target
- Clean build folder: Product > Clean Build Folder (⇧⌘K)
- Restart Xcode

## Next Steps

After setup is complete, you can:
- Customize the Edge Function for additional features
- Add more database tables for screen time tracking
- Implement real-time subscriptions for multi-device sync
- Set up analytics and monitoring

## Security Notes

- Never commit your Supabase keys or OpenAI API key to version control
- Use environment variables or secure configuration for production
- Keep your Edge Function secrets secure
- Regularly rotate API keys

