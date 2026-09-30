// Générateur minimal de PDF valide (1 page, texte). Aucune dépendance.
// Sert à créer des documents de démonstration réellement ouvrables/téléchargeables.

function esc(s) {
  return String(s).replace(/\\/g, "\\\\").replace(/\(/g, "\\(").replace(/\)/g, "\\)");
}

/**
 * @param {string} title  Titre affiché en gros
 * @param {string[]} lines  Lignes de corps
 */
export function makeDemoPdf(title, lines = []) {
  const content = [];
  content.push("BT");
  content.push("/F1 20 Tf");
  content.push("60 770 Td");
  content.push(`(${esc(title)}) Tj`);
  content.push("/F2 11 Tf");
  content.push("0 -34 Td");
  content.push("14 TL");
  for (const l of lines) {
    content.push(`(${esc(l)}) Tj`);
    content.push("T*");
  }
  content.push("ET");
  const stream = content.join("\n");

  const objects = [];
  objects.push("<< /Type /Catalog /Pages 2 0 R >>");
  objects.push("<< /Type /Pages /Kids [3 0 R] /Count 1 >>");
  objects.push(
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] " +
      "/Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> /Contents 4 0 R >>"
  );
  objects.push(`<< /Length ${Buffer.byteLength(stream, "latin1")} >>\nstream\n${stream}\nendstream`);
  objects.push("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>");
  objects.push("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>");

  let pdf = "%PDF-1.4\n%\u00E2\u00E3\u00CF\u00D3\n";
  const offsets = [];
  objects.forEach((body, i) => {
    offsets.push(Buffer.byteLength(pdf, "latin1"));
    pdf += `${i + 1} 0 obj\n${body}\nendobj\n`;
  });

  const xrefPos = Buffer.byteLength(pdf, "latin1");
  const count = objects.length + 1;
  pdf += `xref\n0 ${count}\n`;
  pdf += "0000000000 65535 f \n";
  for (const off of offsets) {
    pdf += String(off).padStart(10, "0") + " 00000 n \n";
  }
  pdf += `trailer\n<< /Size ${count} /Root 1 0 R >>\nstartxref\n${xrefPos}\n%%EOF`;

  return Buffer.from(pdf, "latin1");
}
