const url = "https://wzotqxrmewmgqetpahrm.supabase.co";
const serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6b3RxeHJtZXdtZ3FldHBhaHJtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTA3OTM3MCwiZXhwIjoyMDk2NjU1MzcwfQ.lCRKLa5QBpamzNWsXtykKgxQlmrP2gfaoekojuvjJnU";
const anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6b3RxeHJtZXdtZ3FldHBhaHJtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwNzkzNzAsImV4cCI6MjA5NjY1NTM3MH0.3avna02j3qo-d1r2xyv9yegZ33zIu2Njb-mPSFg7uKM";

const userId = "ff81b0dc-9e23-4718-b2ce-858fa2f30a37";
const email = "pastrola1@gmail.com";
const newPassword = "DebugPassword123!";

async function run() {
  try {
    // 1. Reset password and confirm email via admin API
    console.log(`Resetting password and confirming email for ${email} (${userId})...`);
    const updateRes = await fetch(`${url}/auth/v1/admin/users/${userId}`, {
      method: 'PUT',
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ 
        password: newPassword,
        email_confirm: true 
      })
    });
    
    console.log("Admin update status:", updateRes.status);
    const updateData = await updateRes.json();
    if (!updateRes.ok) {
      console.error("Failed to update user:", updateData);
      return;
    }
    
    // 2. Sign in as user to get JWT
    console.log("Signing in as user to get access token...");
    const loginRes = await fetch(`${url}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: {
        'apikey': anonKey,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        email: email,
        password: newPassword
      })
    });
    
    console.log("Login status:", loginRes.status);
    const loginData = await loginRes.json();
    if (!loginRes.ok) {
      console.error("Login failed:", loginData);
      return;
    }
    
    const accessToken = loginData.access_token;
    console.log("Got access token!");
    
    // 3. Query profiles table
    console.log("Querying profiles table with user JWT...");
    const profileRes = await fetch(`${url}/rest/v1/profiles?id=eq.${userId}`, {
      method: 'GET',
      headers: {
        'apikey': anonKey,
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      }
    });
    
    console.log("Profile query status:", profileRes.status);
    const profileData = await profileRes.json();
    console.log("Profile query response:", JSON.stringify(profileData, null, 2));
    
  } catch (err) {
    console.error("Error:", err);
  }
}

run();
