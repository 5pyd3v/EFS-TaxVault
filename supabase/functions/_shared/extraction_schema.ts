// The schema Gemini's structured-output mode is constrained to (spec §7:
// "Do NOT allow free-form AI responses. Use structured output/schema
// validation."). Kept separate from the canonical DB schema on purpose —
// this is what the model is capable of reading off a page; normalization
// into the canonical invoice happens afterward in index.ts, deterministic
// financial fields (subtotal/tax/total) are never trusted from here alone.

export const EXTRACTION_SCHEMA_VERSION = '1.0';

export const invoiceExtractionResponseSchema = {
  type: 'OBJECT',
  properties: {
    isInvoice: { type: 'BOOLEAN' },
    document: {
      type: 'OBJECT',
      properties: {
        invoiceNumber: {
          type: 'STRING',
          description:
            'The unique identifier printed on the document itself — invoice number, receipt number, bill number, order ID, transaction ID, or token/slip number. Usually near the top, but check headers, footers, and stamps too. Include any leading zeros, dashes, or prefixes exactly as printed.',
        },
        invoiceDate: {
          type: 'STRING',
          description:
            'The transaction/issue date, normalized to ISO 8601 YYYY-MM-DD. Source documents use many formats (DD/MM/YYYY, MM-DD-YY, "5 Jan 2026", "Jan 05, 2026", DD.MM.YYYY) — convert whichever appears. If a printed timestamp includes a time, keep only the date part.',
        },
        currency: { type: 'STRING' },
      },
    },
    supplier: {
      type: 'OBJECT',
      properties: {
        name: { type: 'STRING' },
        ntn: {
          type: 'STRING',
          description:
            'National Tax Number, digits and dashes only. May be labeled "NTN", "NTN#", "Tax No", or "CNIC" on smaller vendors.',
        },
        strn: {
          type: 'STRING',
          description: 'Sales Tax Registration Number, sometimes labeled "STRN" or "GST No".',
        },
        registrationStatus: { type: 'STRING' },
        addressLine: { type: 'STRING' },
        province: { type: 'STRING' },
        city: { type: 'STRING' },
      },
    },
    buyer: {
      type: 'OBJECT',
      properties: {
        name: { type: 'STRING' },
        ntn: { type: 'STRING' },
        strn: { type: 'STRING' },
        registrationStatus: { type: 'STRING' },
        addressLine: { type: 'STRING' },
        province: { type: 'STRING' },
        city: { type: 'STRING' },
      },
    },
    items: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          description: { type: 'STRING' },
          productCode: { type: 'STRING' },
          quantity: { type: 'NUMBER', description: 'Numeric only, e.g. "2 x" -> 2.' },
          unitOfMeasure: { type: 'STRING' },
          unitPrice: {
            type: 'NUMBER',
            description: 'Numeric only, strip currency symbols and thousands separators.',
          },
          discount: { type: 'NUMBER' },
          taxRate: {
            type: 'NUMBER',
            description: 'Percentage as a plain number, e.g. "17%" -> 17, not 0.17.',
          },
          taxAmount: { type: 'NUMBER' },
          totalAmount: { type: 'NUMBER' },
        },
      },
    },
    totals: {
      type: 'OBJECT',
      description:
        'Sum these from the document\'s own printed subtotal/tax/total lines when present, rather than only summing items — printed totals are often more reliable than reconstructing them from a partially-legible item list.',
      properties: {
        subtotal: { type: 'NUMBER', description: 'Amount before tax and before discount.' },
        discount: { type: 'NUMBER' },
        taxableAmount: {
          type: 'NUMBER',
          description: 'The amount sales tax was actually calculated on (subtotal minus discount, usually).',
        },
        salesTax: {
          type: 'NUMBER',
          description:
            'Sales tax / GST / VAT as printed. If several tax lines exist (e.g. federal + provincial, or multiple GST rates), sum them here.',
        },
        otherTaxes: {
          type: 'NUMBER',
          description:
            'Any additional tax/levy that is not sales tax/GST/VAT — e.g. withholding tax, further tax, service charge tax.',
        },
        totalAmount: {
          type: 'NUMBER',
          description: 'The final amount due/paid, as printed — usually the largest, most prominent number on the document.',
        },
      },
    },
    payment: {
      type: 'OBJECT',
      properties: {
        method: { type: 'STRING' },
        reference: { type: 'STRING' },
      },
    },
    confidence: {
      type: 'OBJECT',
      description: 'Score 0-1 per field, only for fields actually populated above.',
      properties: {
        invoiceNumber: { type: 'NUMBER' },
        invoiceDate: { type: 'NUMBER' },
        supplierName: { type: 'NUMBER' },
        supplierNtn: { type: 'NUMBER' },
        items: { type: 'NUMBER' },
        totalAmount: { type: 'NUMBER' },
      },
    },
  },
  required: ['isInvoice'],
};

export interface InvoiceExtractionResult {
  isInvoice: boolean;
  document?: { invoiceNumber?: string; invoiceDate?: string; currency?: string };
  supplier?: PartyExtraction;
  buyer?: PartyExtraction;
  items?: ItemExtraction[];
  totals?: {
    subtotal?: number;
    discount?: number;
    taxableAmount?: number;
    salesTax?: number;
    otherTaxes?: number;
    totalAmount?: number;
  };
  payment?: { method?: string; reference?: string };
  confidence?: Record<string, number>;
}

export interface PartyExtraction {
  name?: string;
  ntn?: string;
  strn?: string;
  registrationStatus?: string;
  addressLine?: string;
  province?: string;
  city?: string;
}

export interface ItemExtraction {
  description?: string;
  productCode?: string;
  quantity?: number;
  unitOfMeasure?: string;
  unitPrice?: number;
  discount?: number;
  taxRate?: number;
  taxAmount?: number;
  totalAmount?: number;
}
