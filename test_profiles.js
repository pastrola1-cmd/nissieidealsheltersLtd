const https = require('https');

function getProfiles() {
  const url = "https://wzotqxrmewmgqetpahrm.supabase.co/rest/v1/profiles?select=*";
  const serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6b3RxeHJtZXdtZ3FldHBhaHJtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTA3OTM3MCwiZXhwIjoyMDk2NjU1MzcwfQ.lCRKLa5QBpamzNWsXtykKgxQlmrP2gfaoekojuvjJnU";
  
  const options = {
    method: 'GET',
    headers: {
      'apikey': serviceRoleKey,
      'Authorization': 'Bearer ' + serviceRoleKey
    }
  };
  
  const req = https.request(url, options, (res) => {
    let data = '';
    res.on('data', (chunk) => {
      data += chunk;
    });
    res.on('end', () => {
      console.log('Status Code:', res.statusCode);
      try {
        const json = JSON.parse(data);
        console.log('Profiles count:', json.length);
        json.forEach(p => {
          console.log(`ID: ${p.id}, Name: ${p.full_name}, Role: ${p.role}, Status: ${p.status}`);
        });
      } catch (e) {
        console.log('Raw output:', data);
      }
    });
  });
  
  req.on('error', (err) => {
    console.error('Error:', err);
  });
  
  req.end();
}

getProfiles();
