import React, {useEffect, useRef, useState} from 'react';
import {reducedMotion} from './ui.jsx';

// Small dependency-free SVG charts. Shapes are plain SVG attributes; the only style set from script is the
// --i stagger index, written through the CSSOM (which the dashboard's strict CSP allows). Motion is CSS (see motion.css);
// this file only decides *when* it starts and passes each shape its position in the stagger via --i.

// Measures the chart box and reports its animation phase:
//   'static' → play nothing (reduced motion / no IntersectionObserver): show the finished chart
//   'pre'    → waiting off-screen: shapes rest in their hidden start state
//   'go'     → scrolled into view: the entrance animation plays once
function useBox() {
  const ref = useRef(null);
  const [width, setWidth] = useState(0);
  const [phase, setPhase] = useState(() => (reducedMotion() || typeof IntersectionObserver === 'undefined' ? 'static' : 'pre'));
  useEffect(() => {
    const el = ref.current;
    if (!el) return undefined;
    setWidth(Math.round(el.getBoundingClientRect().width));
    const observer = new ResizeObserver(([entry]) => setWidth(Math.round(entry.contentRect.width)));
    observer.observe(el);
    return () => observer.disconnect();
  }, []);
  useEffect(() => {
    if (phase !== 'pre') return undefined;
    const io = new IntersectionObserver(([entry]) => { if (entry.isIntersecting) { setPhase('go'); io.disconnect(); } }, {threshold: 0.3});
    io.observe(ref.current);
    return () => io.disconnect();
  }, [phase]);
  return [ref, width, phase === 'static' ? undefined : phase];
}

// Round axis ticks to whole numbers (these charts count appointments).
function scale(max, wanted = 4) {
  const raw = Math.max(max, 1) / wanted;
  const pow = 10 ** Math.floor(Math.log10(raw));
  const f = raw / pow;
  const step = Math.max(1, (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * pow);
  const top = Math.ceil(Math.max(max, 1) / step) * step;
  const ticks = [];
  for (let v = 0; v <= top; v += step) ticks.push(v);
  return {ticks, top};
}

const plural = n => `${n} ${n === 1 ? 'appointment' : 'appointments'}`;

/** Stacked weekly bars: `booked` at the bottom, `pending` on top. */
export function BarChart({labels, titles, booked, pending, height = 150}) {
  const [ref, width, phase] = useBox();
  const totals = booked.map((v, i) => v + pending[i]);
  const {ticks, top} = scale(Math.max(...totals, 0), 2);
  const left = 26, right = 4, topPad = 8, bottom = 22;
  const plotW = Math.max(width - left - right, 10), plotH = height - topPad - bottom;
  const group = plotW / labels.length, barW = Math.min(8, group * 0.42);
  const y = v => topPad + plotH - (v / top) * plotH;
  return (
    <div className="chart" ref={ref}>
      {width > 0 && (
        <svg className={phase} width={width} height={height} role="img" aria-label={`Appointments per day: ${titles.map((t, i) => `${t} ${totals[i]}`).join(', ')}`}>
          {ticks.map(t => (
            <g key={t}>
              <line className="grid" x1={left} x2={width - right} y1={y(t)} y2={y(t)}/>
              <text className="tick" x={left - 8} y={y(t) + 3.5} textAnchor="end">{t}</text>
            </g>
          ))}
          {labels.map((l, i) => {
            const cx = left + group * i + group / 2, h1 = (booked[i] / top) * plotH, h2 = (pending[i] / top) * plotH;
            return (
              <g key={i} className="bar-group">
                <title>{`${titles[i]}: ${plural(totals[i])}${pending[i] ? ` (${pending[i]} pending)` : ''}`}</title>
                <rect className="hit" x={cx - group / 2} y={topPad} width={group} height={plotH}/>
                {h1 > 0 && <rect className="bar booked" style={{'--i': i}} x={cx - barW / 2} y={y(0) - h1} width={barW} height={h1} rx="1.5"/>}
                {h2 > 0 && <rect className="bar pending" style={{'--i': i}} x={cx - barW / 2} y={y(0) - h1 - h2} width={barW} height={h2} rx="1.5"/>}
                <text className="tick" x={cx} y={height - 6} textAnchor="middle">{l}</text>
              </g>
            );
          })}
        </svg>
      )}
    </div>
  );
}

/** Daily line. Points up to `split` are drawn solid (what happened), the rest dotted (what is scheduled). */
export function LineChart({labels, titles, values, split, height = 290}) {
  const [ref, width, phase] = useBox();
  const {ticks, top} = scale(Math.max(...values, 0), 5);
  const left = 34, right = 14, topPad = 12, bottom = 28;
  const plotW = Math.max(width - left - right, 10), plotH = height - topPad - bottom;
  const x = i => left + (values.length > 1 ? (plotW * i) / (values.length - 1) : plotW / 2);
  const y = v => topPad + plotH - (v / top) * plotH;
  const path = (from, to) => values.slice(from, to + 1).map((v, k) => `${k ? 'L' : 'M'}${x(from + k).toFixed(1)} ${y(v).toFixed(1)}`).join(' ');
  const every = width < 420 ? 7 : 5;
  // Each marker pops as the drawing line passes it (solid part), then the scheduled ones follow the dotted line in.
  const DRAW = 1.5;
  const popDelay = i => (i <= split ? 0.3 + (split > 0 ? (i / split) * DRAW : 0) : 0.3 + DRAW + (i - split) * 0.06);
  return (
    <div className="chart" ref={ref}>
      {width > 0 && (
        <svg className={phase} width={width} height={height} role="img" aria-label={`Appointments per day over ${values.length} days`}>
          {ticks.map(t => (
            <g key={t}>
              <line className="grid dashed" x1={left} x2={width - right} y1={y(t)} y2={y(t)}/>
              <text className="tick" x={left - 10} y={y(t) + 3.5} textAnchor="end">{t}</text>
            </g>
          ))}
          {labels.map((l, i) => i % every === 0 ? (
            <text key={i} className="tick" x={x(i)} y={height - 8} textAnchor={i === 0 ? 'start' : 'middle'}>{l}</text>
          ) : null)}
          {split > 0 && <path className="line" pathLength="1" d={path(0, split)}/>}
          {split < values.length - 1 && <path className="line dotted" d={path(Math.max(split, 0), values.length - 1)}/>}
          {values.map((v, i) => (
            <circle key={i} style={{'--d': `${popDelay(i).toFixed(2)}s`}} className={`dot${i === split ? ' today' : ''}${i % 3 === 0 || i === split ? '' : ' quiet'}`} cx={x(i)} cy={y(v)} r={i === split ? 5 : 3.6}>
              <title>{`${titles[i]}: ${plural(v)}`}</title>
            </circle>
          ))}
        </svg>
      )}
    </div>
  );
}

/** Thin horizontal progress bar (soft track + solid fill) that fills once it scrolls into view. */
export function Progress({value, tone = 'primary', label}) {
  const [ref, , phase] = useBox();
  const pct = Math.max(0, Math.min(100, Math.round(value * 100)));
  return (
    <div className="progress-wrap" ref={ref}>
      <svg className={`progress ${tone}${phase ? ` ${phase}` : ''}`} width="100%" height="6" role="img" aria-label={`${label}: ${pct}%`}>
        <rect className="track" width="100%" height="6" rx="3"/>
        {pct > 0 && <rect className="fill" width={`${pct}%`} height="6" rx="3"/>}
      </svg>
    </div>
  );
}
