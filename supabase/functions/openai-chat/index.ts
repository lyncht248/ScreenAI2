// OpenAI Chat Proxy Edge Function
// This function proxies chat requests to OpenAI API, keeping the API key secure on the server

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");

interface RequestBody {
  messages: Array<{
    role: string;
    content?: string | null;
    function_call?: {
      name: string;
      arguments: string;
    };
    tool_calls?: Array<{
      id: string;
      type: string;
      function: {
        name: string;
        arguments: string;
      };
    }>;
    tool_call_id?: string;
    name?: string;
  }>;
  model?: string;
  temperature?: number;
  functions?: Array<Record<string, unknown>>;
  tools?: Array<Record<string, unknown>>;
}

serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    // Get the authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        {
          status: 401,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        }
      );
    }

    // Initialize Supabase client with user's auth token
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    );

    // Verify the user is authenticated
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        {
          status: 401,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        }
      );
    }

    // Check for OpenAI API key
    if (!OPENAI_API_KEY) {
      console.error("OPENAI_API_KEY is not set");
      return new Response(
        JSON.stringify({ error: "Server configuration error" }),
        {
          status: 500,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        }
      );
    }

    // Parse request body
    const requestBody: RequestBody = await req.json();
    
    // Debug logging
    console.log("📥 Received request body keys:", Object.keys(requestBody));
    console.log("📥 Has tools:", !!requestBody.tools, "count:", requestBody.tools?.length ?? 0);
    if (requestBody.tools) {
      console.log("📥 Tools:", JSON.stringify(requestBody.tools).substring(0, 500));
    }

    // Validate request body
    if (!requestBody.messages || !Array.isArray(requestBody.messages)) {
      return new Response(
        JSON.stringify({ error: "Invalid request: messages array required" }),
        {
          status: 400,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        }
      );
    }

    // Prepare OpenAI request
    const openAIRequest: any = {
      model: requestBody.model || "gpt-4o-mini",
      messages: requestBody.messages,
      temperature: requestBody.temperature ?? 0.7,
    };
    
    // Support both tools (newer API) and functions (legacy)
    if (requestBody.tools && requestBody.tools.length > 0) {
      openAIRequest.tools = requestBody.tools;
      console.log("✅ Added tools to OpenAI request");
    } else if (requestBody.functions && requestBody.functions.length > 0) {
      openAIRequest.functions = requestBody.functions;
      console.log("✅ Added functions to OpenAI request");
    } else {
      console.log("⚠️ No tools or functions in request");
    }
    
    console.log("📤 OpenAI request keys:", Object.keys(openAIRequest));
    console.log("📤 OpenAI request has tools:", !!openAIRequest.tools);

    // Call OpenAI API
    const openAIResponse = await fetch(OPENAI_API_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(openAIRequest),
    });

    if (!openAIResponse.ok) {
      const errorText = await openAIResponse.text();
      console.error("OpenAI API error:", errorText);
      return new Response(
        JSON.stringify({ 
          error: "OpenAI API error",
          details: errorText 
        }),
        {
          status: openAIResponse.status,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        }
      );
    }

    const openAIData = await openAIResponse.json();
    
    // Debug: Log OpenAI response
    console.log("📥 OpenAI response has tool_calls:", 
      !!(openAIData.choices?.[0]?.message?.tool_calls?.length));
    if (openAIData.choices?.[0]?.message?.tool_calls) {
      console.log("📥 Tool calls:", JSON.stringify(openAIData.choices[0].message.tool_calls));
    }

    // Return OpenAI response
    return new Response(
      JSON.stringify(openAIData),
      {
        status: 200,
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  } catch (error) {
    console.error("Error in openai-chat function:", error);
    return new Response(
      JSON.stringify({ 
        error: "Internal server error",
        message: error instanceof Error ? error.message : "Unknown error"
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      }
    );
  }
});

