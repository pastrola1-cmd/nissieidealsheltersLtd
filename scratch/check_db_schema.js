const url = "https://wzotqxrmewmgqetpahrm.supabase.co";
const serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6b3RxeHJtZXdtZ3FldHBhaHJtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTA3OTM3MCwiZXhwIjoyMDk2NjU1MzcwfQ.lCRKLa5QBpamzNWsXtykKgxQlmrP2gfaoekojuvjJnU";

async function run() {
  try {
    console.log("Fetching DB OpenAPI schema...");
    const res = await fetch(`${url}/rest/v1/`, {
      method: 'GET',
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': `Bearer ${serviceRoleKey}`
      }
    });

    if (!res.ok) {
      console.error("Failed to fetch schema status:", res.status);
      return;
    }

    const data = await res.json();
    console.log("Tables found in database:");
    const tables = Object.keys(data.definitions);
    console.log(JSON.stringify(tables, null, 2));

    console.log("\nDetails of tables:");
    for (const tableName of tables) {
      const properties = Object.keys(data.definitions[tableName].properties || {});
      console.log(`- Table [${tableName}]: ${properties.join(', ')}`);
    }

  } catch (err) {
    console.error("Error:", err);
  }
}

run();
