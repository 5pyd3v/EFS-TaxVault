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
        invoiceNumber: { type: 'STRING' },
        invoiceDate: { type: 'STRING', description: 'ISO 8601 date, YYYY-MM-DD' },
        currency: { type: 'STRING' },
      },
    },
    supplier: {
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
          quantity: { type: 'NUMBER' },
          unitOfMeasure: { type: 'STRING' },
          unitPrice: { type: 'NUMBER' },
          discount: { type: 'NUMBER' },
          taxRate: { type: 'NUMBER' },
          taxAmount: { type: 'NUMBER' },
          totalAmount: { type: 'NUMBER' },
        },
      },
    },
    totals: {
      type: 'OBJECT',
      properties: {
        subtotal: { type: 'NUMBER' },
        discount: { type: 'NUMBER' },
        taxableAmount: { type: 'NUMBER' },
        salesTax: { type: 'NUMBER' },
        otherTaxes: { type: 'NUMBER' },
        totalAmount: { type: 'NUMBER' },
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
