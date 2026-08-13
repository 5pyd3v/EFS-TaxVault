-- Reconstructs the canonical invoice JSON (spec §4) from the relational
-- source of truth. This is NOT an FBR payload — it is the internal
-- canonical representation an FBRInvoicePayloadAdapter would consume once
-- the official FBR schema exists (spec §5). The database, not any stored
-- AI output, is always what this is generated from — call it any time and
-- it reflects current, possibly user-corrected, values.

create or replace function public.get_canonical_invoice_json(p_invoice_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_invoice record;
  v_supplier record;
  v_customer record;
  v_items jsonb;
  v_result jsonb;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if not found then
    raise exception 'invoice not found';
  end if;
  if not public.is_org_member(v_invoice.organization_id) then
    raise exception 'not authorized';
  end if;

  if v_invoice.supplier_id is not null then
    select * into v_supplier from public.suppliers where id = v_invoice.supplier_id;
  end if;
  if v_invoice.customer_id is not null then
    select * into v_customer from public.customers where id = v_invoice.customer_id;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'description', description,
        'productCode', product_code,
        'quantity', quantity,
        'unitOfMeasure', unit_of_measure,
        'unitPrice', unit_price,
        'discount', discount,
        'taxableAmount', taxable_amount,
        'taxRate', tax_rate,
        'taxAmount', tax_amount,
        'totalAmount', total_amount
      )
      order by line_no
    ),
    '[]'::jsonb
  )
  into v_items
  from public.invoice_items
  where invoice_id = p_invoice_id;

  v_result := jsonb_build_object(
    'schemaVersion', v_invoice.schema_version,
    'document', jsonb_build_object(
      'documentType', v_invoice.document_type,
      'invoiceNumber', v_invoice.invoice_number,
      'invoiceDate', v_invoice.invoice_date,
      'currency', v_invoice.currency
    ),
    'supplier', case when v_supplier.id is not null then jsonb_build_object(
      'name', v_supplier.name,
      'ntn', v_supplier.ntn,
      'strn', v_supplier.strn,
      'registrationStatus', v_supplier.registration_status,
      'address', v_supplier.address,
      'province', v_supplier.province,
      'city', v_supplier.city
    ) else '{}'::jsonb end,
    'buyer', case when v_customer.id is not null then jsonb_build_object(
      'name', v_customer.name,
      'ntn', v_customer.ntn,
      'strn', v_customer.strn,
      'registrationStatus', v_customer.registration_status,
      'address', v_customer.address,
      'province', v_customer.province,
      'city', v_customer.city
    ) else '{}'::jsonb end,
    'items', v_items,
    'totals', jsonb_build_object(
      'subtotal', v_invoice.subtotal,
      'discount', v_invoice.discount,
      'taxableAmount', v_invoice.taxable_amount,
      'salesTax', v_invoice.sales_tax,
      'otherTaxes', v_invoice.other_taxes,
      'totalAmount', v_invoice.total_amount
    ),
    'payment', jsonb_build_object(
      'method', v_invoice.payment_method,
      'reference', v_invoice.payment_reference
    ),
    'tax', jsonb_build_object(
      'taxPeriod', to_char(v_invoice.invoice_date, 'YYYY-MM'),
      'taxType', 'sales_tax'
    ),
    'references', jsonb_build_object(
      'invoiceId', v_invoice.id,
      'documentId', v_invoice.document_id,
      'documentHash', v_invoice.document_hash
    ),
    'ai', jsonb_build_object(
      'confidence', v_invoice.ai_confidence,
      'calculationMismatch', v_invoice.calculation_mismatch
    ),
    'verification', jsonb_build_object(
      'status', v_invoice.verification_status,
      'verifiedByUser', v_invoice.verified_by is not null,
      'verifiedAt', v_invoice.verified_at
    )
  );

  return v_result;
end;
$$;

grant execute on function public.get_canonical_invoice_json(uuid) to authenticated;
