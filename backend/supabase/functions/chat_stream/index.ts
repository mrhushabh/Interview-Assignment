/// <reference path="../deno.d.ts" />


//CHAT STREAM EDGE FUNCTION


import { createClient } from "https://esm.sh/@supabase/supabase-js@2.47.0";

// CORS headers
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// GEMINI API CONFIGURATION

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:streamGenerateContent";

interface ChatRequest {
  session_id: string;
  message: string;
}


async function streamGeminiResponse(
  message: string,
  conversationHistory: Array<{ role: string; content: string }>
): Promise<ReadableStream<Uint8Array>> {

  const contents = conversationHistory.map((msg) => ({
    role: msg.role === "user" ? "user" : "model",
    parts: [{ text: msg.content }],
  }));


  contents.push({
    role: "user",
    parts: [{ text: message }],
  });

  const response = await fetch(`${GEMINI_API_URL}?key=${GEMINI_API_KEY}&alt=sse`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      contents,
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 1024,
      },
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Gemini API error: ${response.status} - ${error}`);
  }

  return response.body!;
}

// Parse Gemini SSE stream

async function* parseGeminiStream(
  stream: ReadableStream<Uint8Array>
): AsyncGenerator<string, void, unknown> {
  const reader = stream.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });

      // Process complete SSE messages
      const lines = buffer.split("\n");
      buffer = lines.pop() || ""; 

      for (const line of lines) {
        if (line.startsWith("data: ")) {
          const jsonStr = line.slice(6).trim();
          if (jsonStr && jsonStr !== "[DONE]") {
            try {
              const data = JSON.parse(jsonStr);
              // Extract text from Gemini response format
              const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
              if (text) {
                yield text;
              }
            } catch {
              // Skip invalid JSON
            }
          }
        }
      }
    }
  } finally {
    reader.releaseLock();
  }
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

    const { session_id, message }: ChatRequest = await req.json();

    if (!session_id || !message) {
      return new Response(
        JSON.stringify({ error: "Missing session_id or message" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. VERIFY SESSION OWNERSHIP (RLS will also check this)
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


    // 4. SAVE USER MESSAGE TO DATABASE

    const { error: userMsgError } = await supabaseClient
      .from("chat_messages")
      .insert({
        session_id,
        role: "user",
        content: message,
      });

    if (userMsgError) {
      console.error("Failed to save user message:", userMsgError);
      return new Response(
        JSON.stringify({ error: "Failed to save message" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }


    // 5. FETCH CONVERSATION HISTORY FOR CONTEXT

    const { data: history } = await supabaseClient
      .from("chat_messages")
      .select("role, content")
      .eq("session_id", session_id)
      .order("created_at", { ascending: true })
      .limit(20); // Limit context to last 20 messages

    const conversationHistory = history || [];

    // 6. STREAM RESPONSE FROM GEMINI
 
    const encoder = new TextEncoder();
    let fullResponse = "";

    const responseStream = new ReadableStream({
      async start(controller) {
        try {
          // Get streaming response from Gemini
          const geminiStream = await streamGeminiResponse(message, conversationHistory);

          // Parse and forward each chunk
          for await (const chunk of parseGeminiStream(geminiStream)) {
            fullResponse += chunk;
            // Send as SSE format
            const sseData = `data: ${JSON.stringify({ content: chunk })}\n\n`;
            controller.enqueue(encoder.encode(sseData));
          }


          // 7. SAVE ASSISTANT RESPONSE TO DATABASE
          if (fullResponse.trim()) {
            const { error: assistantMsgError } = await supabaseClient
              .from("chat_messages")
              .insert({
                session_id,
                role: "assistant",
                content: fullResponse.trim(),
              });

            if (assistantMsgError) {
              console.error("Failed to save assistant message:", assistantMsgError);
            }
          }

          // Update session's updated_at timestamp
          await supabaseClient
            .from("chat_sessions")
            .update({ updated_at: new Date().toISOString() })
            .eq("id", session_id);

          controller.close();
        } catch (error) {
          console.error("Streaming error:", error);
          const errorData = `data: ${JSON.stringify({ error: error.message })}\n\n`;
          controller.enqueue(encoder.encode(errorData));
          controller.close();
        }
      },
      cancel() {
        // Handle client cancellation
        console.log("Stream cancelled by client");
      },
    });

    // Return SSE response
    return new Response(responseStream, {
      headers: {
        ...corsHeaders,
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
      },
    });

  } catch (error) {
    console.error("Request error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
