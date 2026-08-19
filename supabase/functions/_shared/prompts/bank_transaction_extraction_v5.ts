// v5: same extraction rules as v4 (counterpartyName is ALWAYS the sender —
// see v4's header for the ISP use-case reasoning that motivated it), but
// rewritten for token efficiency. v4 spent ~3x the input tokens restating
// the same rules in prose across long bullet lists; on a free-tier key
// where per-minute token limits are the dominant cause of failures, prompt
// size is paid on every single scan. Two substantive changes beyond
// trimming:
//   - fullText now asks only for the identity lines (names/accounts), not
//     a transcript of the whole receipt. It exists solely to feed the
//     regex safety net in index.ts, which only ever looks at the
//     name-plus-IBAN pattern, so transcribing totals/fees/footers was pure
//     output-token waste.
//   - Confidence scoring is requested only for fields where it actually
//     drives UI (low-confidence warnings), not for every field.
// v1-v4 are kept as historical records of what earlier ai_extractions rows
// were produced by — never edit them in place; add v6 instead.
export const BANK_TRANSACTION_EXTRACTION_PROMPT_VERSION = 'bank_transaction_extraction_v5';

export const BANK_TRANSACTION_EXTRACTION_PROMPT =
  `Extract payment data from this Pakistani bank/wallet transaction receipt (Meezan, UBL, HBL, Alfalah, NayaPay, SadaPay, EasyPaisa, JazzCash, Raast, etc.). Read the whole image including small print.

Fields:
- direction: "debit" if money left the account holder, "credit" if received.
- amount: number only, no currency symbol or commas.
- currency, bankName, referenceNumber (any transaction/reference/MSGID/STAN), status (as printed).
- transactionDate: ISO 8601. Include time as HH:mm:ss when shown ("2026-08-06T17:59:00"), else "YYYY-MM-DD". Output ONLY the timestamp — never append notes or explanation to this field.

counterpartyName — ALWAYS the SENDER (who paid), never the receiver, regardless of debit/credit:
- Prefer an explicit sender label: "From", "Sending from", "Sender", "Paid by", "Debit Account Title". That name is the counterparty.
- Ignore names labeled "To", "Receiver", "Receiver Name", "Beneficiary", "Consumer name" — those are the receiving account, not the counterparty.
- If NO sender label exists anywhere (common on Raast P2P receipts that only show money going "to" someone), the account holder shown near "A/C Number" or at the top is the sender — use that name, not the "to" name.
- When a name is embedded in a dense run-on line, it is the block of 2-5 Title Case/ALL CAPS words; stop at the first token starting with "PK"+2 digits (IBAN, e.g. "PK88TMFB...") or mixing capitals with digits/masking. From that token onward is counterpartyAccount; the long alphanumeric string after it is referenceNumber.
- Examples: "From Noman Ali ... Receiver Name MUHAMMAD QASIM" -> "Noman Ali". "Sending from AFSHEEN BIBI/SHAHID IQBAL ... Sending to MUHAMMAD QASIM" -> "AFSHEEN BIBI/SHAHID IQBAL". "Money Received from SANA BUTT SADAPAY XXXX1234567890 STAN(112233)" -> name "SANA BUTT", account "SADAPAY XXXX1234567890", reference "112233".

- counterpartyAccount: the sender's account/IBAN exactly as printed, keeping any masking.
- fullText: ONLY the lines naming the sender/receiver and their account numbers (typically 2-4 lines). Do not transcribe amounts, fees, or footers.
- confidence: 0-1 scores for amount, transactionDate, counterpartyName only. Score counterpartyName lower when inferred from a run-on line or from an absent sender label.

Do not invent values that aren't visible, but do give a best reading of a blurry or run-on field rather than leaving it blank. If the image isn't a transaction receipt, set isBankTransaction false and leave other fields empty. Return only the structured data — no explanation, no markdown.`;
