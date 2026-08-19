# SehatLink V2 — Patient navigation MVP

## What is new
- 2-step patient journey: short history → payment step
- Case ID generation for the prototype
- Dedicated workflow page
- Privacy & safety page
- Designed for eventual secure backend + doctor dashboard
- Better positioning: healthcare navigation, not automated diagnosis
- Mobile-responsive design
- Payment provider placeholders for JazzCash/Easypaisa/card
- Clear emergency escalation language

## IMPORTANT
This is still a FRONT-END PROTOTYPE. The form does not transmit or store the patient's health history. Do not accept real patient cases through this version.

For a production service, implement:
1. Secure backend/database with encryption, authentication, role-based access and audit logs.
2. Verified payment gateway.
3. Doctor/staff dashboard with case assignment, status, timestamps and internal notes.
4. Secure patient communication.
5. Verified specialist/hospital directory.
6. Consent/privacy/retention policy reviewed for Pakistan.
7. Emergency/red-flag escalation protocol.
8. Verified PM&DC credentials and professional scope for the four founders.
9. Professional/legal review before public launch.

## GitHub Pages
Upload all files to a GitHub repository. Settings → Pages → Deploy from branch → main → /(root).

## Suggested real workflow
Patient submits → payment confirmed → case ID created → assigned doctor reviews → follow-up → specialty selected → nearby verified options → patient receives referral.

## Production architecture suggestion
Frontend: GitHub Pages / similar static host
Backend: secure managed application backend
Database: encrypted managed database
Auth: staff-only MFA
Messaging: verified business WhatsApp/SMS provider
Payments: licensed/appropriate payment provider
Directory: verified doctors/hospitals, searchable by specialty + city
