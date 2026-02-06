// @ts-ignore: deno.d.ts is for IDE only, Deno has built-in types
import { assertEquals, assertExists } from "https://deno.land/std@0.168.0/testing/asserts.ts";


// Test: SSE message formatting

Deno.test("SSE message format is correct", () => {
  const content = "Hello world";
  const sseMessage = `data: ${JSON.stringify({ content })}\n\n`;
  
  // Verify format
  assertEquals(sseMessage.startsWith("data: "), true);
  assertEquals(sseMessage.endsWith("\n\n"), true);
  
  // Verify JSON is parseable
  const jsonPart = sseMessage.replace("data: ", "").replace("\n\n", "");
  const parsed = JSON.parse(jsonPart);
  assertEquals(parsed.content, "Hello world");
});


// Test: Message validation
Deno.test("Request validation catches missing fields", () => {
  const validateRequest = (body: { session_id?: string; message?: string }) => {
    if (!body.session_id || !body.message) {
      return { valid: false, error: "Missing session_id or message" };
    }
    return { valid: true };
  };

  // Missing both
  assertEquals(validateRequest({}).valid, false);
  
  // Missing message
  assertEquals(validateRequest({ session_id: "123" }).valid, false);
  
  // Missing session_id
  assertEquals(validateRequest({ message: "hello" }).valid, false);
  
  // Valid request
  assertEquals(validateRequest({ session_id: "123", message: "hello" }).valid, true);
});


//Test: Conversation history formatting

Deno.test("Conversation history formats correctly for Gemini", () => {
  const history = [
    { role: "user", content: "Hello" },
    { role: "assistant", content: "Hi there!" },
    { role: "user", content: "How are you?" },
  ];
  
  // Convert to Gemini format
  const geminiFormat = history.map((msg) => ({
    role: msg.role === "user" ? "user" : "model",
    parts: [{ text: msg.content }],
  }));
  
  assertEquals(geminiFormat.length, 3);
  assertEquals(geminiFormat[0].role, "user");
  assertEquals(geminiFormat[1].role, "model");
  assertEquals(geminiFormat[2].role, "user");
  assertEquals(geminiFormat[0].parts[0].text, "Hello");
});


// Test: UUID validation helper
Deno.test("UUID validation works correctly", () => {
  const isValidUUID = (str: string) => {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    return uuidRegex.test(str);
  };
  
  // Valid UUIDs
  assertEquals(isValidUUID("550e8400-e29b-41d4-a716-446655440000"), true);
  assertEquals(isValidUUID("6ba7b810-9dad-11d1-80b4-00c04fd430c8"), true);
  
  // Invalid UUIDs
  assertEquals(isValidUUID("not-a-uuid"), false);
  assertEquals(isValidUUID("123"), false);
  assertEquals(isValidUUID(""), false);
});
