import React, {useCallback, useEffect, useLayoutEffect, useRef, useState} from 'react';

// Presentation helpers shared by every screen. Nothing here touches data or API state.

const glyphs = {
  dashboard: <><rect x="3" y="3" width="7" height="9" rx="1.5"/><rect x="14" y="3" width="7" height="5" rx="1.5"/><rect x="14" y="12" width="7" height="9" rx="1.5"/><rect x="3" y="16" width="7" height="5" rx="1.5"/></>,
  users: <><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></>,
  calendar: <><rect x="3" y="4" width="18" height="18" rx="2.5"/><path d="M16 2v4M8 2v4M3 10h18"/></>,
  calendarPlus: <><path d="M21 13V6.5A2.5 2.5 0 0 0 18.5 4h-13A2.5 2.5 0 0 0 3 6.5v13A2.5 2.5 0 0 0 5.5 22H13"/><path d="M16 2v4M8 2v4M3 10h18M19 16v6M16 19h6"/></>,
  calendarCheck: <><rect x="3" y="4" width="18" height="18" rx="2.5"/><path d="M16 2v4M8 2v4M3 10h18"/><path d="m9 16 2 2 4-4"/></>,
  checks: <><path d="m3 17 2 2 4-4"/><path d="m3 7 2 2 4-4"/><path d="M13 6h8M13 12h8M13 18h8"/></>,
  message: <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>,
  file: <><path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7z"/><path d="M14 2v4a2 2 0 0 0 2 2h4M10 9H8M16 13H8M16 17H8"/></>,
  shield: <><path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/></>,
  history: <><path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5M12 7v5l4 2"/></>,
  sliders: <path d="M21 4h-7M10 4H3M21 12h-9M8 12H3M21 20h-5M12 20H3M14 2v4M8 10v4M16 18v4"/>,
  plus: <path d="M12 5v14M5 12h14"/>,
  search: <><circle cx="11" cy="11" r="7.5"/><path d="m21 21-4.35-4.35"/></>,
  x: <path d="M18 6 6 18M6 6l12 12"/>,
  logout: <><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5M21 12H9"/></>,
  chevronRight: <path d="m9 18 6-6-6-6"/>,
  chevronLeft: <path d="m15 18-6-6 6-6"/>,
  chevronDown: <path d="m6 9 6 6 6-6"/>,
  refresh: <><path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16M8 16H3v5"/></>,
  pin: <><path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/></>,
  inbox: <><path d="M22 12h-6l-2 3h-4l-2-3H2"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/></>,
  alert: <><circle cx="12" cy="12" r="10"/><path d="M12 8v4M12 16h.01"/></>,
  clock: <><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></>,
  userPlus: <><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M19 8v6M22 11h-6"/></>,
  send: <><path d="m22 2-7 20-4-9-9-4z"/><path d="M22 2 11 13"/></>,
  check: <path d="M20 6 9 17l-5-5"/>,
  arrowRight: <path d="M5 12h14M12 5l7 7-7 7"/>,
  lock: <><rect x="3" y="11" width="18" height="11" rx="2.5"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></>,
  mail: <><rect x="2" y="4" width="20" height="16" rx="2.5"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></>,
  phone: <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z"/>,
  trend: <><path d="m22 7-8.5 8.5-5-5L2 17"/><path d="M16 7h6v6"/></>,
  hourglass: <><path d="M5 22h14M5 2h14"/><path d="M17 22v-4.17a2 2 0 0 0-.59-1.42L12 12l-4.41 4.41A2 2 0 0 0 7 17.83V22M7 2v4.17a2 2 0 0 0 .59 1.42L12 12l4.41-4.41A2 2 0 0 0 17 6.17V2"/></>,
  edit: <><path d="M12 20h9"/><path d="M16.38 3.62a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4z"/></>,
  pulse: <path d="M22 12h-4l-3 9L9 3l-3 9H2"/>,
  menu: <path d="M4 6h16M4 12h16M4 18h16"/>,
};

// Duotone icons for navigation, stat chips and empty states: solid front shape over a 40% back shape.
const stroke = {fill: 'none', stroke: 'currentColor', strokeWidth: 2, strokeLinecap: 'round', strokeLinejoin: 'round'};
const duotones = {
  dashboard: <><rect x="3" y="3" width="8" height="10" rx="2.5"/><rect x="13" y="3" width="8" height="6" rx="2.5" opacity=".4"/><rect x="13" y="11" width="8" height="10" rx="2.5"/><rect x="3" y="15" width="8" height="6" rx="2.5" opacity=".4"/></>,
  users: <><circle cx="9" cy="7.5" r="4"/><path d="M1.5 19.5c0-3 3.2-5 7.5-5s7.5 2 7.5 5c0 .8-.7 1.5-1.5 1.5h-12c-.8 0-1.5-.7-1.5-1.5z"/><circle cx="17.5" cy="8.5" r="3" opacity=".4"/><path opacity=".4" d="M18.3 14.2c2.2.4 3.7 1.8 3.7 3.8 0 .6-.4 1-1 1h-2.4c.3-.5.4-1 .4-1.6 0-1.4-.3-2.6-.7-3.2z"/></>,
  calendar: <><rect x="3" y="5" width="18" height="16" rx="3" opacity=".4"/><path d="M3 10.5V8a3 3 0 0 1 3-3h12a3 3 0 0 1 3 3v2.5z"/><rect x="7" y="2.5" width="2" height="5" rx="1"/><rect x="15" y="2.5" width="2" height="5" rx="1"/><rect x="7" y="13.5" width="3" height="3" rx=".8"/></>,
  calendarPlus: <><rect x="3" y="5" width="18" height="16" rx="3" opacity=".4"/><path d="M3 10.5V8a3 3 0 0 1 3-3h12a3 3 0 0 1 3 3v2.5z"/><rect x="7" y="2.5" width="2" height="5" rx="1"/><rect x="15" y="2.5" width="2" height="5" rx="1"/><path d="M12 12.5v5M9.5 15h5" {...stroke}/></>,
  checks: <><rect x="4" y="4" width="16" height="18" rx="3" opacity=".4"/><rect x="8" y="2" width="8" height="4.5" rx="2"/><path d="m8.5 14.5 2.3 2.3 4.7-4.8" {...stroke}/></>,
  message: <><path opacity=".4" d="M5 3h14a3 3 0 0 1 3 3v8a3 3 0 0 1-3 3h-8l-5 4v-4H5a3 3 0 0 1-3-3V6a3 3 0 0 1 3-3z"/><rect x="6.5" y="7.5" width="11" height="2" rx="1"/><rect x="6.5" y="11" width="6.5" height="2" rx="1"/></>,
  file: <><path opacity=".4" d="M6 2h7.5L20 8.5V19a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V5a3 3 0 0 1 3-3z"/><path d="M13.5 2v4a2.5 2.5 0 0 0 2.5 2.5H20z"/><rect x="7" y="12.5" width="10" height="2" rx="1"/><rect x="7" y="16.5" width="6.5" height="2" rx="1"/></>,
  shield: <><path opacity=".4" d="M12 2 4 5.5V12c0 4.8 3.3 8.3 8 10 4.7-1.7 8-5.2 8-10V5.5z"/><path d="m8.5 12 2.5 2.5 4.5-4.5" {...stroke}/></>,
  history: <><circle cx="12" cy="12" r="10" opacity=".4"/><path d="M11 6.5h2v5.2l3.3 2-1 1.7-4.3-2.6z"/></>,
  sliders: <><rect x="3" y="5" width="18" height="2.5" rx="1.25" opacity=".4"/><rect x="3" y="10.75" width="18" height="2.5" rx="1.25" opacity=".4"/><rect x="3" y="16.5" width="18" height="2.5" rx="1.25" opacity=".4"/><circle cx="8" cy="6.25" r="3"/><circle cx="16" cy="12" r="3"/><circle cx="10" cy="17.75" r="3"/></>,
  userPlus: <><circle cx="9" cy="7.5" r="4"/><path d="M1.5 19.5c0-3 3.2-5 7.5-5 1 0 1.9.1 2.8.4A6.5 6.5 0 0 0 11 21H3c-.8 0-1.5-.7-1.5-1.5z"/><circle cx="18" cy="16" r="5" opacity=".4"/><path d="M18 13.5v5M15.5 16h5" {...stroke}/></>,
  hourglass: <><path opacity=".4" d="M6 2h12v4.5a3 3 0 0 1-1 2.2L13.5 12l3.5 3.3a3 3 0 0 1 1 2.2V22H6v-4.5a3 3 0 0 1 1-2.2L10.5 12 7 8.7a3 3 0 0 1-1-2.2z"/><rect x="4" y="1.5" width="16" height="2.5" rx="1.250"/><rect x="4" y="20" width="16" height="2.5" rx="1.250"/></>,
  trend: <><rect x="3" y="13" width="4.5" height="8" rx="1.5" opacity=".4"/><rect x="9.750" y="8" width="4.5" height="13" rx="1.5" opacity=".7"/><rect x="16.5" y="3" width="4.5" height="18" rx="1.5"/></>,
  mail: <><rect x="2" y="4.5" width="20" height="15" rx="3" opacity=".4"/><path d="m4 8 8 5.5L20 8" {...stroke}/></>,
  checkCircle: <><circle cx="12" cy="12" r="10" opacity=".4"/><path d="m7.5 12.5 3 3 6-6.5" {...stroke}/></>,
  crossCircle: <><circle cx="12" cy="12" r="10" opacity=".4"/><path d="m9 9 6 6M15 9l-6 6" {...stroke}/></>,
  inbox: <><path opacity=".4" d="M3 13 5.3 5.5A2.5 2.5 0 0 1 7.7 3.7h8.6a2.5 2.5 0 0 1 2.4 1.8L21 13v5a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3z"/><path d="M3 13h5.5l1 2.5h5l1-2.5H21v1.5a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3z"/></>,
};

export function Duo({name, size = 20, className = ''}) {
  return <svg className={`glyph ${className}`.trim()} width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" focusable="false">{duotones[name] || duotones.inbox}</svg>;
}

export function Icon({name, size = 18, className = ''}) {
  return <svg className={`glyph ${className}`.trim()} width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">{glyphs[name]}</svg>;
}

export const human = value => value?.toLowerCase().replaceAll('_',' ').replace(/^./, c=>c.toUpperCase());

export const initials = name => {
  const parts = String(name || '').replace(/^(dr|mr|mrs|ms)\.?\s+/i, '').trim().split(/\s+/).filter(Boolean);
  return ((parts[0]?.[0] || '') + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase() || '·';
};

const tone = name => { let h = 0; for (const c of String(name || '')) h = (h * 31 + c.charCodeAt(0)) % 6; return h; };

export function Avatar({name, size = 'md'}) {
  return <span className={`avatar ${size} tone-${tone(name)}`} aria-hidden="true">{initials(name)}</span>;
}

export const fullDate = value => {
  const d = new Date(`${value}T00:00:00`);
  return Number.isNaN(d.getTime()) ? value : d.toLocaleDateString('en-GB', {weekday: 'long', day: 'numeric', month: 'long'});
};

export function Badge({value}) { return <span className={`badge ${value?.toLowerCase()}`}>{human(value)}</span>; }

export function Notice({error}) {
  return error && <div className="notice" role="alert"><Icon name="alert" size={16}/><div>{error.message || String(error)}{error.requestId && <small>Reference: {error.requestId}</small>}</div></div>;
}

export function Empty({children, icon = 'inbox', compact}) {
  return <div className={`empty${compact ? ' compact' : ''}`}><span className="empty-icon"><Duo name={icon} size={24}/></span><div>{children}</div></div>;
}

// ── Motion helpers ──────────────────────────────────────────────────────────────────────────

/** True when the visitor asked their system for less motion. Every JS animation checks this first. */
export const reducedMotion = () => typeof window !== 'undefined' && !!window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;

/**
 * Counts up to `value` with an ease-out-expo curve, and glides between values when the data refreshes.
 * Screen readers get the final number only; non-numeric values (like "–") are shown as they are.
 */
export function CountUp({value, duration = 1100}) {
  const target = Number(value);
  const numeric = value !== null && value !== '' && Number.isFinite(target);
  const [shown, setShown] = useState(() => (numeric && !reducedMotion() ? 0 : target));
  const from = useRef(shown);
  useEffect(() => {
    if (!numeric) return undefined;
    if (reducedMotion()) { from.current = target; setShown(target); return undefined; }
    const origin = Number.isFinite(from.current) ? from.current : 0, start = performance.now();
    let frame;
    const tick = now => {
      const t = Math.min(1, Math.max(0, (now - start) / duration));
      const current = origin + (target - origin) * (t === 1 ? 1 : 1 - 2 ** (-10 * t));
      from.current = current;
      setShown(current);
      if (t < 1) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [target, numeric, duration]);
  if (!numeric) return <>{value}</>;
  const display = Number.isFinite(shown) ? Math.round(shown) : reducedMotion() ? target : 0;
  return <><span aria-hidden="true">{display}</span><span className="sr-only">{target}</span></>;
}

/**
 * Tab strip with a single underline that glides to the active tab. The buttons stay ordinary
 * `<button aria-pressed>` elements owned by the caller; this only measures and positions the indicator.
 */
export function Segmented({active, className = '', children, ...rest}) {
  const ref = useRef(null);
  const [settled, setSettled] = useState(false);
  const place = useCallback(() => {
    const el = ref.current, on = el?.querySelector('[aria-pressed="true"]');
    if (!el || !on) return;
    const width = Math.min(on.offsetWidth * 0.6, 64);
    el.style.setProperty('--ind-w', `${width}px`);
    el.style.setProperty('--ind-x', `${on.offsetLeft + (on.offsetWidth - width) / 2}px`);
    el.style.setProperty('--ind-o', '1');
  }, []);
  useLayoutEffect(() => { place(); }, [active, place]);
  useEffect(() => {
    const observer = new ResizeObserver(place);
    observer.observe(ref.current);
    // Turn transitions on only after the first placement, so the underline never slides in from the left on load.
    const frame = requestAnimationFrame(() => setSettled(true));
    return () => { observer.disconnect(); cancelAnimationFrame(frame); };
  }, [place]);
  return <div ref={ref} className={`segmented ${className}${settled ? ' settled' : ''}`.trim()} {...rest}>{children}</div>;
}
