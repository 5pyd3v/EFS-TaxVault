-- Fixes a real bug in get_canonical_invoice_json: v_supplier/v_customer
-- were declared as `record` and only populated via a conditional
-- `select into` when supplier_id/customer_id was present. Since buyer
-- extraction isn't wired up yet, customer_id is null on effectively every
-- invoice — so `v_customer.id` was read on a record that was never
-- assigned, which Postgres raises as a hard error ("record ... is not
-- assigned yet"), not a null. Every "Export canonical JSON" tap on a
-- buyer-less invoice hit this. Fixed by building each party directly as
-- jsonb, defaulting to '{}' instead of touching an unassigned record.

create or replace function public.get_canonical_invoice_json(p_invoice_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_invoice record;
  v_supplier_json jsonb := '{}'::jsonb;
  v_customer_json jsonb := '{}'::jsonb;
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
    select coalesce(jsonb_build_object(
      'name', name,
      'ntn', ntn,
      'strn', strn,
      'registrationStatus', registration_status,
      'address', address,
      'province', province,
      'city', city
    ), '{}'::jsonb)
    into v_supplier_json
    from public.suppliers where id = v_invoice.supplier_id;
    v_supplier_json := coalesce(v_supplier_json, '{}'::jsonb);
  end if;

  if v_invoice.customer_id is not null then
    select coalesce(jsonb_build_object(
      'name', name,
      'ntn', ntn,
      'strn', strn,
      'registrationStatus', registration_status,
      'address', address,
      'province', province,
      'city', city
    ), '{}'::jsonb)
    into v_customer_json
    from public.customers where id = v_invoice.customer_id;
    v_customer_json := coalesce(v_customer_json, '{}'::jsonb);
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
    'supplier', v_supplier_json,
    'buyer', v_customer_json,
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
