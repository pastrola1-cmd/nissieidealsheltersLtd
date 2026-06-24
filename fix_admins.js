const https = require('https');

function fixAdmins() {
  const supabaseUrl = "https://wzotqxrmewmgqetpahrm.supabase.co";
  const serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6b3RxeHJtZXdtZ3FldHBhaHJtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTA3OTM3MCwiZXhwIjoyMDk2NjU1MzcwfQ.lCRKLa5QBpamzNWsXtykKgxQlmrP2gfaoekojuvjJnU";
  
  // Endpoint to update profiles table where role is admin
  const url = new URL(supabaseUrl + "/rest/v1/profiles?role=eq.admin");
  
  const payload = JSON.stringify({
    status: 'approved'
  });
  
  const options = {
    hostname: url.hostname,
    port: 443,
    path: url.pathname + url.search,
    method: 'PATCH',
    headers: {
      'apikey': serviceRoleKey,
      'Authorization': 'Bearer ' + serviceRoleKey,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation'
    }
  };
  
  const req = https.request(options, (res) => {
    let data = '';
    console.log('Status Code:', res.statusCode);
    
    res.on('data', (chunk) => {
      data += chunk;
    });
    
    res.on('end', () => {
      console.log('Response:', data);
    });
  });
  
  req.on('error', (err) => {
    console.error('Error:', err);
  });
  
  req.write(payload);
  req.end();
}

fixAdmins();
