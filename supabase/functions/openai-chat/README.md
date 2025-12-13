# OpenAI Chat Proxy Edge Function

This Edge Function proxies chat requests to the OpenAI API, keeping your API key secure on the server.

## Deployment

1. Install Supabase CLI: `npm install -g supabase`

2. Login to Supabase: `supabase login`

3. Link your project: `supabase link --project-ref YOUR_PROJECT_REF`

4. Set the OpenAI API key as a secret:
   ```
   supabase secrets set OPENAI_API_KEY=your_openai_api_key_here
   ```

5. Deploy the function:
   ```
   supabase functions deploy openai-chat
   ```

## Usage

The function expects:
- Authorization header with Supabase JWT token
- POST request with JSON body containing:
  - `messages`: Array of chat messages
  - `model`: OpenAI model (default: "gpt-4o-mini")
  - `temperature`: Optional temperature (default: 0.7)
  - `functions`: Optional function definitions

## Security

- Requires authenticated Supabase user
- API key is stored as a server-side secret
- Rate limiting can be added via Supabase dashboard

