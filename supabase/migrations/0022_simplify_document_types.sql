-- Collapses the document-type taxonomy from 5 categories down to 2:
-- 'invoice' and 'bank_transaction'. 'receipt' / 'tax_document' / 'other'
-- were all processed through the exact same extract-invoice pipeline as
-- 'invoice' with no behavioral difference — the distinction only added a
-- confusing extra step to the scan-type picker with no payoff. Bank
-- transactions already have their own dedicated pipeline/table, so the
-- real, meaningful split is just invoice vs. bank transaction.

-- Normalize any existing rows before narrowing the constraint, so this
-- migration is safe to run against a database that already has
-- 'receipt'/'tax_document'/'other' rows from before this change.
update public.documents
  set document_type = 'invoice'
  where document_type in ('receipt', 'tax_document', 'other');

update public.invoices
  set document_type = 'invoice'
  where document_type in ('receipt', 'tax_document', 'other');

alter table public.documents
  drop constraint documents_document_type_check,
  add constraint documents_document_type_check
    check (document_type in ('invoice', 'bank_transaction'));
