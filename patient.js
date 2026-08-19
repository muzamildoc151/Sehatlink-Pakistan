import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";
import { SUPABASE_URL,SUPABASE_ANON_KEY } from "./config.js";
const form=document.getElementById("caseForm"), msg=document.getElementById("message");
form.addEventListener("submit",async e=>{
 e.preventDefault();
 if(!SUPABASE_URL||!SUPABASE_ANON_KEY){msg.textContent="Backend not configured. Add Supabase values to config.js first.";return;}
 const file=document.getElementById("receipt").files[0];
 if(!file){msg.textContent="Please select a receipt.";return;}
 if(file.size>5*1024*1024){msg.textContent="Receipt must be 5 MB or smaller.";return;}
 const allowed=["image/jpeg","image/png","image/webp","application/pdf"];
 if(!allowed.includes(file.type)){msg.textContent="Use JPG, PNG, WEBP or PDF.";return;}
 msg.textContent="Submitting securely…";
 const d=Object.fromEntries(new FormData(form).entries());
 const supabase=createClient(SUPABASE_URL,SUPABASE_ANON_KEY);
 const {data:code,error}=await supabase.rpc("create_patient_case",{
  p_name:d.name,p_age:Number(d.age),p_gender:d.gender,p_location:d.location,p_phone:d.phone,
  p_problem:d.problem,p_duration:d.duration,p_severity:d.severity,p_symptoms:d.symptoms||null,
  p_conditions:d.conditions||null,p_medicines:d.medicines||null,p_tests:d.tests||null
 });
 if(error){msg.textContent="Could not create case: "+error.message;return;}
 const {data:caseRow,error:caseError}=await supabase.from("cases").select("id").eq("case_code",code).single();
 if(caseError){msg.textContent="Case created but receipt step failed. Contact the team with case "+code;return;}
 const path=code+"/"+crypto.randomUUID()+"-"+file.name.replace(/[^a-zA-Z0-9._-]/g,"_");
 const {error:uploadError}=await supabase.storage.from("payment-receipts").upload(path,file,{contentType:file.type,upsert:false});
 if(uploadError){msg.textContent="Case "+code+" created, but receipt upload failed: "+uploadError.message;return;}
 const {error:updateError}=await supabase.from("payments").update({
  sender_name:d.sender_name,sender_phone:d.sender_phone,transaction_reference:d.transaction_reference,
  receipt_path:path
 }).eq("case_id",caseRow.id);
 if(updateError){msg.textContent="Case "+code+" created, but receipt metadata failed. Do not resubmit repeatedly; contact the team.";return;}
 msg.innerHTML="<b>Request submitted.</b> Your case ID is <b>"+code+"</b>. Payment is pending manual verification.";
 form.reset();
});