const url = "https://wzotqxrmewmgqetpahrm.supabase.co";
const serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6b3RxeHJtZXdtZ3FldHBhaHJtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTA3OTM3MCwiZXhwIjoyMDk2NjU1MzcwfQ.lCRKLa5QBpamzNWsXtykKgxQlmrP2gfaoekojuvjJnU";

async function run() {
  try {
    console.log("Checking users in Supabase Auth...");
    const res = await fetch(`${url}/auth/v1/admin/users`, {
      method: 'GET',
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': `Bearer ${serviceRoleKey}`
      }
    });

    if (!res.ok) {
      console.error("Failed to fetch users status:", res.status);
      const errText = await res.text();
      console.error(errText);
      return;
    }

    const data = await res.json();
    console.log(`Total users found: ${data.users.length}`);
    
    const targetEmail = "daricholamide1@gmail.com";
    const user = data.users.find(u => u.email.toLowerCase() === targetEmail.toLowerCase());
    
    if (user) {
      console.log(`\nUser found:`);
      console.log(`ID: ${user.id}`);
      console.log(`Email: ${user.email}`);
      console.log(`Email Confirmed At: ${user.email_confirmed_at}`);
      console.log(`Phone: ${user.phone}`);
      console.log(`Last Sign In: ${user.last_sign_in_at}`);
      console.log(`Metadata:`, JSON.stringify(user.user_metadata, null, 2));
    } else {
      console.log(`\nUser with email "${targetEmail}" does NOT exist in Supabase Auth.`);
      console.log("Existing users in database:");
      data.users.forEach(u => {
        console.log(`- ${u.email} (ID: ${u.id}, Created: ${u.created_at})`);
      });
    }

  } catch (err) {
    console.error("Error:", err);
  }
}

run();
