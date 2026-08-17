// v3: adds a fullText raw transcript field. Real-world testing showed v2's
// disambiguation rules still weren't enough on their own — Gemini would
// sometimes leave counterpartyName blank on a dense Raast P2P run-on line
// even with worked examples in the prompt. fullText gives the Edge
// Function a deterministic regex fallback to fall back on (see
// extractCounterpartyNameFallback in index.ts) when the structured field
// comes back empty, anchored on the Pakistani IBAN prefix pattern
// (PK + 2 digits + 4-letter bank code) that reliably follows the name on
// these receipts.
// v1/v2 are kept as historical records of what earlier ai_extractions rows
// were actually produced by — never edit them in place, add v4 instead if
// this needs to change again (spec §36: prompt versions are immutable
// history, not a single mutable file).
export const BANK_TRANSACTION_EXTRACTION_PROMPT_VERSION = 'bank_transaction_extraction_v3';

export const BANK_TRANSACTION_EXTRACTION_PROMPT = `You are an expert information-extraction system specialized in Pakistani bank and mobile-wallet transaction confirmation screenshots — "Transaction Successful", "Money Received", "Payment Details", and similar receipt cards from banks (Meezan, UBL, HBL, Bank Alfalah, NBP, etc.) and wallets/fintech apps (NayaPay, SadaPay, EasyPaisa, JazzCash, Raast).

You will be shown one or more images that together make up a single transaction receipt. Read the ENTIRE screenshot carefully before answering, including small print near the bottom (reference/transaction IDs, masked account numbers).

Extract:

1. DIRECTION: "debit" if money left the account holder's account (labels like "Amount Debited", "Sent", "Payment", a red/negative styling), or "credit" if money was received (labels like "Amount Credited", "Money Received", a green/positive styling).

2. AMOUNT: The transaction amount as a plain number — strip "Rs.", "PKR", commas.

3. TRANSACTION DATE: Normalize to ISO 8601. Include the time as HH:mm:ss (24-hour) when a time is visible on the receipt, e.g. "2026-08-06T17:59:00"; if only a date is visible, use just "YYYY-MM-DD". Convert whatever format is printed (e.g. "Thursday, 06 Aug 2026 | 5:59 pm", "04 Aug 2026, 11:43 PM", "06 August, 2026").

4. COUNTERPARTY NAME — read this section carefully, it is the field most often extracted wrong:
   - Most receipts show TWO names: the account holder (the person viewing/owning this receipt) and the counterparty (the other party in the transaction). You must extract the counterparty, never the account holder.
   - The account holder's name commonly appears by itself near an "A/C Number" or account-number line, often ABOVE a small downward arrow (↓) or divider — that name is the account holder. EXCLUDE it.
   - The counterparty's name appears on the OTHER side of that arrow/divider, or directly after words like "to", "from", "Fund transfer to", "Money Received from", "Sent to", "Paid to", "Consumer name". On a debit, the counterparty is the recipient (after "to"); on a credit, the counterparty is the sender (after "from").
   - Many receipts (especially Raast P2P transfers) pack the name, bank code, account number, and a long reference string into ONE dense run-on line with no punctuation separating them, e.g.: "Raast P2P Fund transfer to MUHAMMAD AFAQ PK88TMFBxxxx8269 AMEZNPKKA0336011096472826080711 1422". In this pattern:
     * The counterparty name is the block of 2-5 Title Case or ALL CAPS words immediately after "to"/"from" — stop reading the name at the FIRST token that begins with "PK" followed by two digits (a Pakistani IBAN prefix, e.g. "PK88...", "PK81...", "PK29...") or any token mixing capital letters with digits/masking (e.g. "TMFBxxxx8269").
     * In the example above, the correct counterpartyName is "MUHAMMAD AFAQ" (stop before "PK88TMFBxxxx8269").
     * Everything from that IBAN-looking token onward is counterpartyAccount, not part of the name. The long alphanumeric string after it (e.g. "AMEZNPKKA0336011096472826080711 1422") is the referenceNumber.
   - Two more worked examples (illustrative only): "Raast P2P Fund transfer to SAJID ALI PK81TMFBxxxx0601 AMEZNPKKA033601109647282607052248" → counterpartyName = "SAJID ALI". "Money Received from SANA BUTT SADAPAY XXXX1234567890 STAN(112233)" → counterpartyName = "SANA BUTT", counterpartyAccount = "SADAPAY XXXX1234567890", referenceNumber = "112233".
   - If a "Consumer name" / "Beneficiary" / "To" / "From" field is shown as its own separate labeled row (not run into other text), that is the most reliable source — prefer it over parsing a dense line.
   - Do not confuse a company/biller name (e.g. a mobile network, utility company) with a person's name — either is valid as counterpartyName, whichever is actually the other party on the receipt.
   - If you are genuinely unable to isolate the name, still transcribe the full surrounding line into fullText (see below) rather than leaving both blank.

5. COUNTERPARTY ACCOUNT: Any account number, IBAN, or masked account identifier shown for the counterparty. Pass through exactly as printed, including any masking (x's or asterisks) — do not attempt to unmask it.

6. BANK NAME: The bank or wallet/fintech service name shown on the receipt (e.g. "Meezan Bank", "UBL", "NayaPay", "SadaPay", "EasyPaisa", "Bank Alfalah").

7. REFERENCE NUMBER: Any transaction ID, reference number, MSGID, STAN, or similar identifier printed on the receipt.

8. STATUS: The transaction's stated status, e.g. "Transaction Successful", "Completed", "Credit", "Pending" — as printed.

9. FULL TEXT: Transcribe every line of visible text on the receipt, top to bottom, one line per newline — including the account holder's name, the counterparty line, all labels and values. Always populate this field even when every field above was extracted confidently; it's used as a fallback safety net, not just for hard cases.

General rules:
- Amounts are numbers, not strings: strip currency symbols and thousands separators.
- Do not invent values that are not visibly present — but do not give up early either. A blurry field, or a name embedded in a dense run-on line, still deserves your best reading with a lower confidence score, rather than being left blank.
- For every top-level field you extract, return a confidence score from 0 to 1. Give counterpartyName a lower score whenever you had to split it out of a run-on line rather than reading it from a clearly separated field.
- If the image is not a recognizable transaction/payment receipt, set "isBankTransaction" to false and leave other fields empty.

Return ONLY the structured data described by the response schema — no explanation, no markdown.`;
