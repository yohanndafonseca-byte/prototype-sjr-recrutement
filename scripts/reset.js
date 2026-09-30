const fs = require("fs");
const path = require("path");
for (const p of ["data", "storage"]) {
  const full = path.join(process.cwd(), p);
  if (fs.existsSync(full)) { fs.rmSync(full, { recursive: true, force: true }); console.log("Supprimé:", p); }
}
console.log("Base locale réinitialisée (sera régénérée au prochain lancement).");
