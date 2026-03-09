// Content Safety Filter for Kawabel
// Filters both student input and AI output to ensure safe, educational interactions

// --- Blocklists ---

const INDONESIAN_PROFANITY = [
  'bodoh', 'goblok', 'anjing', 'babi', 'bangsat', 'kampret',
  'kontol', 'memek', 'ngentot', 'tai', 'tolol', 'bego',
  'bajingan', 'keparat', 'setan', 'iblis', 'brengsek',
  'asu', 'jancok', 'cok', 'pepek', 'titit', 'ngewe',
];

const ENGLISH_PROFANITY = [
  'fuck', 'shit', 'ass', 'bitch', 'damn', 'dick', 'cock',
  'pussy', 'bastard', 'cunt', 'whore', 'slut', 'nigger',
  'faggot', 'retard', 'penis', 'vagina', 'boob', 'porn',
  'nude', 'naked', 'sex',
];

const PROMPT_INJECTION_PATTERNS = [
  /ignore\s+(previous|your|all|the)\s+(instructions?|prompts?|rules?)/i,
  /forget\s+(your|all|the)\s+(instructions?|prompts?|rules?)/i,
  /you\s+are\s+now/i,
  /pretend\s+(to\s+be|you\s*'?re)/i,
  /act\s+as\s+(a|an|if)/i,
  /new\s+instructions?/i,
  /system\s+prompt/i,
  /jailbreak/i,
  /bypass\s+(filter|safety|restriction)/i,
  /override\s+(your|the)\s+(instructions?|rules?|programming)/i,
  /disregard\s+(your|all|previous)/i,
  /do\s+not\s+follow\s+(your|the)\s+(instructions?|rules?)/i,
  /ignore\s+everything\s+(above|before)/i,
  /from\s+now\s+on\s+you\s+(are|will)/i,
  /roleplay\s+as/i,
  /developer\s+mode/i,
  /DAN\s+mode/i,
];

const PERSONAL_INFO_PATTERNS = [
  /(?:what'?s?|give|tell|share|send)\s+(?:me\s+)?(?:your|my|their|his|her)\s+(?:home\s+)?address/i,
  /(?:what'?s?|give|tell|share|send)\s+(?:me\s+)?(?:your|my|their|his|her)\s+password/i,
  /(?:credit|debit)\s+card\s+(?:number|info|detail)/i,
  /(?:alamat\s+rumah|alamat\s+lengkap)/i,
  /(?:kata\s+sandi|password)/i,
  /(?:nomor\s+(?:kartu\s+kredit|rekening|ktp|identitas))/i,
  /(?:pin\s+(?:atm|bank|kartu))/i,
];

/**
 * Check if text contains any word from a blocklist.
 * Uses word-boundary matching to avoid false positives
 * (e.g., "assistant" should not match "ass").
 */
function containsBlockedWord(text, wordList) {
  const lower = text.toLowerCase();
  for (const word of wordList) {
    // Use word boundary regex to avoid partial matches
    const regex = new RegExp(`\\b${escapeRegex(word)}\\b`, 'i');
    if (regex.test(lower)) {
      return word;
    }
  }
  return null;
}

function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Filter student input before sending to AI.
 * @param {string} text - The student's message
 * @returns {{ safe: boolean, reason: string }}
 */
function filterInput(text) {
  if (!text || typeof text !== 'string') {
    return { safe: true, reason: '' };
  }

  // Check Indonesian profanity
  const idWord = containsBlockedWord(text, INDONESIAN_PROFANITY);
  if (idWord) {
    return { safe: false, reason: `Kata tidak pantas terdeteksi: "${idWord}"` };
  }

  // Check English profanity
  const enWord = containsBlockedWord(text, ENGLISH_PROFANITY);
  if (enWord) {
    return { safe: false, reason: `Inappropriate language detected` };
  }

  // Check prompt injection attempts
  for (const pattern of PROMPT_INJECTION_PATTERNS) {
    if (pattern.test(text)) {
      return { safe: false, reason: 'Prompt injection attempt detected' };
    }
  }

  // Check personal info fishing
  for (const pattern of PERSONAL_INFO_PATTERNS) {
    if (pattern.test(text)) {
      return { safe: false, reason: 'Personal information request detected' };
    }
  }

  return { safe: true, reason: '' };
}

/**
 * Filter AI output before showing to student.
 * @param {string} text - The AI's response
 * @returns {{ safe: boolean, cleaned: string }}
 */
function filterOutput(text) {
  if (!text || typeof text !== 'string') {
    return { safe: true, cleaned: text || '' };
  }

  // Check for profanity leaking through
  const idWord = containsBlockedWord(text, INDONESIAN_PROFANITY);
  if (idWord) {
    return { safe: false, cleaned: 'Maaf, Kawi tidak bisa menjawab itu. Coba tanya pertanyaan lain ya!' };
  }

  const enWord = containsBlockedWord(text, ENGLISH_PROFANITY);
  if (enWord) {
    return { safe: false, cleaned: 'Maaf, Kawi tidak bisa menjawab itu. Coba tanya pertanyaan lain ya!' };
  }

  // Check for direct homework answers without explanation
  // Pattern: response that is just a number (likely a direct answer)
  const trimmed = text.trim();
  if (/^\d+([.,]\d+)?$/.test(trimmed) && trimmed.length < 10) {
    return {
      safe: false,
      cleaned: 'Kawi tidak boleh kasih jawaban langsung ya! Yuk kita pelajari caranya bersama. Coba ceritakan soalnya, dan Kawi bantu langkah-langkahnya.',
    };
  }

  // Check for "the answer is X" patterns without steps
  const directAnswerPatterns = [
    /^(?:jawabannya|jawaban(?:nya)?\s+adalah|the\s+answer\s+is)\s*[:=]?\s*\d/i,
  ];
  for (const pattern of directAnswerPatterns) {
    if (pattern.test(trimmed) && trimmed.length < 50) {
      return {
        safe: false,
        cleaned: 'Kawi tidak boleh kasih jawaban langsung ya! Yuk kita pelajari caranya bersama. Coba ceritakan soalnya, dan Kawi bantu langkah-langkahnya.',
      };
    }
  }

  return { safe: true, cleaned: text };
}

module.exports = { filterInput, filterOutput };
