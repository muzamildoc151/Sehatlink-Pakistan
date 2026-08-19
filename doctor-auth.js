import {createClient} from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";import{SUPABASE_URL,SUPABASE_ANON_KEY}from"./config.js";
const msg=document.getElementById("msg");const form=document.getElementById("loginForm");
form.addEventListener("submit",async e=>{e.preventDefault();if(!SUPABASE_URL||!SUPABASE_ANON_KEY){msg.textContent="Configure config.js first.";return;}
const s=createClient(SUPABASE_URL,SUPABASE_ANON_KEY);const{error}=await s.auth.signInWithPassword({email:email.value,password:password.value});
if(error){msg.textContent=error.message;return;}location.href="dashboard.html";});