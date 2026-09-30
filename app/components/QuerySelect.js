"use client";
import { useRouter, useSearchParams, usePathname } from "next/navigation";

export default function QuerySelect({ param, value, options, allLabel = "Tous" }) {
  const router = useRouter();
  const path = usePathname();
  const sp = useSearchParams();
  function onChange(e) {
    const params = new URLSearchParams(sp.toString());
    if (e.target.value) params.set(param, e.target.value);
    else params.delete(param);
    router.push(`${path}?${params.toString()}`);
  }
  return (
    <select className="field w-auto min-w-[200px]" value={value || ""} onChange={onChange}>
      <option value="">{allLabel}</option>
      {options.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
    </select>
  );
}
