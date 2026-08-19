-- On-device OCR text captured at scan time, so extraction can send text to
-- Gemini instead of the page image.
--
-- Why: a receipt image costs roughly 1,500-2,500 input tokens and requires
-- the slow vision path, while the same receipt as plain text is ~200
-- tokens on the fast text path. Measured behaviour on this project was
-- 6-8s for a successful vision extraction but a 24% overall success rate,
-- dominated by 503-overload and quota errors — both of which are driven by
-- request cost and volume against a rate-limited key. Recognizing the text
-- on-device first (ML Kit, free, offline, no quota) removes most of that
-- cost from the API call entirely.
--
-- Nullable on purpose: OCR is best-effort. When it yields too little text
-- to trust (a dark photo, an unusual layout), the Edge Functions fall back
-- to sending the image, so this is an optimization rather than a new hard
-- dependency in the scan path.

alter table public.documents
  add column ocr_text text;

comment on column public.documents.ocr_text is
  'Raw text recognized on-device at scan time. Used as the preferred Gemini input; falls back to page images when null or too short.';
