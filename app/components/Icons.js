const base = { fill: "none", stroke: "currentColor", strokeWidth: 1.8, strokeLinecap: "round", strokeLinejoin: "round" };
const S = ({ children, className = "w-5 h-5", ...p }) => (
  <svg viewBox="0 0 24 24" className={className} {...base} {...p}>{children}</svg>
);
export const IconSearch = (p) => (<S {...p}><circle cx="11" cy="11" r="7" /><path d="m21 21-4.3-4.3" /></S>);
export const IconPin = (p) => (<S {...p}><path d="M12 21s7-6.2 7-11a7 7 0 1 0-14 0c0 4.8 7 11 7 11Z" /><circle cx="12" cy="10" r="2.5" /></S>);
export const IconClock = (p) => (<S {...p}><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></S>);
export const IconBriefcase = (p) => (<S {...p}><rect x="3" y="7" width="18" height="13" rx="2" /><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 12h18" /></S>);
export const IconUsers = (p) => (<S {...p}><circle cx="9" cy="8" r="3.2" /><path d="M2.5 20a6.5 6.5 0 0 1 13 0M16 5.5a3 3 0 0 1 0 5.4M17 14.2A6 6 0 0 1 21.5 20" /></S>);
export const IconBuilding = (p) => (<S {...p}><rect x="4" y="3" width="16" height="18" rx="1.5" /><path d="M8 7h2M14 7h2M8 11h2M14 11h2M8 15h2M14 15h2M10 21v-3h4v3" /></S>);
export const IconChevron = (p) => (<S {...p}><path d="m9 6 6 6-6 6" /></S>);
export const IconArrowLeft = (p) => (<S {...p}><path d="M19 12H5M11 6l-6 6 6 6" /></S>);
export const IconCheck = (p) => (<S {...p}><path d="M20 6 9 17l-5-5" /></S>);
export const IconDownload = (p) => (<S {...p}><path d="M12 3v12M7 11l5 5 5-5M4 21h16" /></S>);
export const IconLogout = (p) => (<S {...p}><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" /></S>);
export const IconDoc = (p) => (<S {...p}><path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z" /><path d="M14 3v5h5M9 13h6M9 17h6" /></S>);
export const IconLayers = (p) => (<S {...p}><path d="m12 3 9 5-9 5-9-5 9-5ZM3 13l9 5 9-5" /></S>);
export const IconGauge = (p) => (<S {...p}><path d="M12 13.5 15 9M21 14a9 9 0 1 0-18 0" /><circle cx="12" cy="14" r="1.4" /></S>);
export const IconAlert = (p) => (<S {...p}><path d="M12 9v4M12 17h.01M10.3 3.9 2 18a1.7 1.7 0 0 0 1.5 2.6h17A1.7 1.7 0 0 0 22 18L13.7 3.9a2 2 0 0 0-3.4 0Z" /></S>);
export const IconGrid = (p) => (<S {...p}><rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" /><rect x="3" y="14" width="7" height="7" rx="1" /><rect x="14" y="14" width="7" height="7" rx="1" /></S>);
export const IconInbox = (p) => (<S {...p}><path d="M3 13h4l2 3h6l2-3h4" /><path d="M5 5h14l3 8v6a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1v-6z" /></S>);
export const IconStar = (p) => (<S {...p}><path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8-5.2-2.7L6.8 19.7l1-5.8L3.5 9.7l5.9-.9z" /></S>);
export const IconPlus = (p) => (<S {...p}><path d="M12 5v14M5 12h14" /></S>);
