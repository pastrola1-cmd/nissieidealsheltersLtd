const url = "https://wzotqxrmewmgqetpahrm.supabase.co";
const serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6b3RxeHJtZXdtZ3FldHBhaHJtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTA3OTM3MCwiZXhwIjoyMDk2NjU1MzcwfQ.lCRKLa5QBpamzNWsXtykKgxQlmrP2gfaoekojuvjJnU";

async function run() {
  try {
    const res = await fetch(`${url}/rest/v1/`, {
      headers: { 'apikey': serviceRoleKey, 'Authorization': `Bearer ${serviceRoleKey}` }
    });
    const data = await res.json();
    console.log("RPC paths:");
    const rpcs = Object.keys(data.paths).filter(p => p.startsWith("/rpc/"));
    console.log(rpcs);
  } catch (err) {
    console.error(err);
  }
}
run();
