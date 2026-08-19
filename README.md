# SehatLink V4 — payment + receipt + backend starter

## Included
- GitHub Pages-compatible frontend
- Supabase database/Auth integration
- Patient history form
- JazzCash manual-payment instructions
- Payment receipt upload to a PRIVATE Supabase Storage bucket
- Manual payment verification workflow
- Doctor login/dashboard
- Verified consultant directory
- 200 fictional/demo consultant records in SQL (hidden from public results)
- RLS starter policies

## JazzCash payment
The patient page currently displays:
- Account: 03120510151
- Account title: Muzamil Fiaz
- Amount: Rs. 200

The patient submits sender name, sender number, transaction/reference number and a receipt file.

## Critical setup
1. Create a Supabase project.
2. Run `supabase-schema.sql`.
3. Create a PRIVATE Storage bucket named `payment-receipts`.
4. Add storage RLS policies that allow only active doctors to read receipt objects and allow the patient submission mechanism to upload. Review these policies carefully before real use.
5. Create four doctor Auth accounts.
6. Add their UUIDs and names to `doctor_roles`.
7. Copy `config.example.js` to `config.js` and add your project URL + browser-safe publishable/anon key.
8. Upload the site to GitHub Pages.
9. Test only with fake data/receipts first.

## Payment verification
The browser must NEVER decide that a payment is approved. A doctor should inspect the receipt/reference and then set the payment status to approved/rejected. In production, consider adding an audit log and a dedicated payment-review screen.

## 200 consultant directory
The SQL contains 200 entries named "Demo Consultant 001" through "Demo Consultant 200". They are deliberately fictional and `is_demo=true`, `verified=false`, so they do not appear in the public directory. Do NOT change those flags to make them look real.

Before launch, replace them with consultants whose identity, specialty, registration, clinic and contact details have actually been verified.

## Security
Never put a Supabase secret/service-role key in GitHub or browser JavaScript. Use only the browser-safe publishable/anon key with correctly configured RLS. Keep private receipt storage private.

## Medical/legal
This starter does not constitute a medical diagnosis system. Before real launch, obtain appropriate professional, privacy, security and legal review in Pakistan, establish consent/retention/deletion policies, an emergency escalation process, doctor credential verification, and incident response.
