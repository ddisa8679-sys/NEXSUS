const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");

initializeApp();

const groqApiKey = defineSecret("GROQ_API_KEY");

exports.askJarvis = onCall(
  { secrets: [groqApiKey], timeoutSeconds: 60, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to NEXSUS first.");
    }

    const input = request.data && request.data.messages;
    if (!Array.isArray(input) || input.length === 0 || input.length > 16) {
      throw new HttpsError("invalid-argument", "A short conversation history is required.");
    }

    const messages = input.map((item) => {
      const role = item && item.role;
      const content = item && item.content;
      if (!["user", "assistant"].includes(role) ||
          typeof content !== "string" || content.length > 6000) {
        throw new HttpsError("invalid-argument", "Invalid message.");
      }
      return { role, content };
    });

    const apiKey = groqApiKey.value();
    if (!apiKey) {
      throw new HttpsError("failed-precondition", "Groq API key is not configured.");
    }

    let response;
    try {
      response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          model: "openai/gpt-oss-120b",
          temperature: 0.7,
          max_completion_tokens: 1200,
          messages: [
            {
              role: "system",
              content: "Ты — Джарвис, голосовой ИИ-помощник приложения NEXSUS. Всегда отвечай на русском языке, если пользователь сам не попросил другой язык. Будь дружелюбным, спокойным, умным и конкретным. Отвечай естественно, как личный помощник. Не выдумывай факты и прямо говори, если чего-то не знаешь. Не утверждай, что выполнил действия на телефоне или в интернете, если у тебя нет соответствующего инструмента."
            },
            ...messages
          ]
        })
      });
    } catch (_) {
      throw new HttpsError("unavailable", "Could not reach Groq.");
    }

    if (!response.ok) {
      const status = response.status;
      if (status === 429) {
        throw new HttpsError("resource-exhausted", "Groq rate limit reached.");
      }
      console.error("Groq API error:", status, await response.text());
      throw new HttpsError("unavailable", "The AI service is temporarily unavailable.");
    }

    const data = await response.json();
    const reply = data.choices && data.choices[0] &&
      data.choices[0].message && data.choices[0].message.content;
    if (typeof reply !== "string" || !reply.trim()) {
      throw new HttpsError("internal", "The AI service returned an empty response.");
    }
    return { reply: reply.trim() };
  }
);
