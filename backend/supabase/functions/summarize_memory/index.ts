/// <reference path="../deno.d.ts" />

 //SUMMARIZE MEMORY EDGE FUNCTION

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.47.0";

// CORS headers
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// GEMINI API CONFIGURATION

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "YOUR_GEMINI_API_KEY_HERE";
const GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";

interface SummarizeRequest {
  session_id: string;
}

// Call Gemini API to generate a summary

async function generateSummary(conversationText: string): Promise<string> {
  const prompt = `You are a helpful assistant that creates concise memory summaries.

Analyze the following conversation and create a brief summary (2-3 sentences) that captures:
- Key topics discussed
- Important information shared by the user
- Any preferences or facts learned about the user

Conversation:
${conversationText}

Summary:`;

  const response = await fetch(`${GEMINI_API_URL}?key=${GEMINI_API_KEY}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      contents: [
        {
          role: "user",
          parts: [{ text: prompt }],
        },
      ],
      generationConfig: {
        temperature: 0.3, 
        maxOutputTokens: 256,
      },
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Gemini API error: ${response.status} - ${error}`);
  }

  const data = await response.json();
  const summary = data?.candidates?.[0]?.content?.parts?.[0]?.text;

  if (!summary) {
    throw new Error("No summary generated from Gemini");
  }

  return summary.trim();
}


// MAIN REQUEST HANDLER
Deno.serve(async (req) => {

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. AUTHENTICATE THE USER
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Create Supabase client with user's auth token
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    // 2. PARSE AND VALIDATE REQUEST
    const { session_id }: SummarizeRequest = await req.json();

    if (!session_id) {
      return new Response(
        JSON.stringify({ error: "Missing session_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. VERIFY SESSION OWNERSHIP
    const { data: session, error: sessionError } = await supabaseClient
      .from("chat_sessions")
      .select("id, user_id")
      .eq("id", session_id)
      .single();

    if (sessionError || !session) {
      return new Response(
        JSON.stringify({ error: "Session not found or access denied" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. FETCH ALL MESSAGES FROM SESSION
    const { data: messages, error: messagesError } = await supabaseClient
      .from("chat_messages")
      .select("role, content")
      .eq("session_id", session_id)
      .order("created_at", { ascending: true });

    if (messagesError) {
      return new Response(
        JSON.stringify({ error: "Failed to fetch messages" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!messages || messages.length === 0) {
      return new Response(
        JSON.stringify({ error: "No messages found in session" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. FORMAT CONVERSATION FOR SUMMARIZATION
    const conversationText = messages
      .map((msg) => `${msg.role.toUpperCase()}: ${msg.content}`)
      .join("\n\n");

    // 6. GENERATE SUMMARY WITH GEMINI

    const summary = await generateSummary(conversationText);

    // 7. SAVE MEMORY TO DATABASE
    const { data: memory, error: memoryError } = await supabaseClient
      .from("memories")
      .insert({
        user_id: session.user_id,
        session_id,
        summary,
      })
      .select()
      .single();

    if (memoryError) {
      console.error("Failed to save memory:", memoryError);
      return new Response(
        JSON.stringify({ error: "Failed to save memory" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 8. RETURN SUCCESS
    return new Response(
      JSON.stringify({ memory }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Request error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
