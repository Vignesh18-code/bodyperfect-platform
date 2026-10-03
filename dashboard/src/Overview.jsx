import React, {useEffect, useMemo, useState} from 'react';
import {api, params} from './api.js';
import {Icon, Duo, Avatar, Badge, CountUp, Segmented, fullDate} from './ui.jsx';
import {BarChart, LineChart, Progress} from './charts.jsx';

// ── date helpers (local dates as YYYY-MM-DD, like the rest of the dashboard) ──
const pad = n => String(n).padStart(2, '0');
const iso = d => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const parse = s => { const [y, m, d] = s.split('-').map(Number); return new Date(y, m - 1, d); };
export const addDays = (s, n) => { const d = parse(s); d.setDate(d.getDate() + n); return iso(d); };
const validDay = s => /^\d{4}-\d{2}-\d{2}$/.test(s || '');
const relative = date => {
  const diff = Math.round((parse(date) - parse(iso(new Date()))) / 864e5);
  return diff === 0 ? 'Today' : diff === 1 ? 'Tomorrow' : diff === -1 ? 'Yesterday' : parse(date).toLocaleDateString('en-GB', {weekday: 'short', day: 'numeric', month: 'short'});
};

const BOOKED = ['CONFIRMED', 'CHECKED_IN', 'IN_CONSULTATION', 'COMPLETED'];
const LOST = ['CANCELLED', 'NO_SHOW'];
const PAGE_SIZE = 100, MAX_PAGES = 5, BEFORE = 14, AFTER = 15;

// Every appointment from 14 days before to 15 days after the selected day, read through the
// existing staff appointments endpoint (date range, 100 per page).
function useSchedule(branch, day) {
  const [state, setState] = useState({loading: true});
  useEffect(() => {
    if (!validDay(day)) { setState({loading: false, items: []}); return; }
    const abort = new AbortController();
    setState({loading: true});
    (async () => {
      try {
        const from = addDays(day, -BEFORE), to = addDays(day, AFTER);
        let items = [], page = 0, hasNext = true;
        while (hasNext && page < MAX_PAGES) {
          const res = await api.request('/api/staff/appointments?' + params({branch, from, to, page, size: PAGE_SIZE}), {signal: abort.signal});
          items = items.concat(res.items);
          hasNext = res.hasNext;
          page++;
        }
        setState({loading: false, items, truncated: hasNext});
      } catch (e) { if (e.name !== 'AbortError') setState({loading: false, error: e}); }
    })();
    return () => abort.abort();
  }, [branch, day]);
  return state;
}

function summarize(items, day) {
  const week = Array.from({length: 7}, (_, i) => addDays(day, i));
  const span = Array.from({length: BEFORE + AFTER + 1}, (_, i) => addDays(day, i - BEFORE));
  const byDate = new Map();
  for (const a of items) { if (!byDate.has(a.date)) byDate.set(a.date, []); byDate.get(a.date).push(a); }
  const on = d => byDate.get(d) || [];
  const sorted = [...items].sort((a, b) => (a.date + a.time).localeCompare(b.date + b.time));
  const past = span.slice(0, BEFORE).flatMap(on);
  const nextUp = [], seen = new Set();
  for (const a of sorted) {
    if (a.date < day || LOST.includes(a.status) || a.status === 'COMPLETED' || seen.has(a.patientId)) continue;
    seen.add(a.patientId); nextUp.push(a);
    if (nextUp.length === 5) break;
  }
  return {
    weekLabels: week.map(d => 'SMTWTFS'[parse(d).getDay()]),
    weekTitles: week.map(d => parse(d).toLocaleDateString('en-GB', {weekday: 'short', day: 'numeric', month: 'short'})),
    booked: week.map(d => on(d).filter(a => BOOKED.includes(a.status)).length),
    pending: week.map(d => on(d).filter(a => a.status === 'PENDING').length),
    spanLabels: span.map(d => parse(d).toLocaleDateString('en-GB', {day: 'numeric', month: 'short'})),
    spanTitles: span.map(d => parse(d).toLocaleDateString('en-GB', {weekday: 'short', day: 'numeric', month: 'short'})),
    volume: span.map(d => on(d).filter(a => !LOST.includes(a.status)).length),
    pastTotal: past.length,
    completed: past.filter(a => a.status === 'COMPLETED').length,
    lost: past.filter(a => LOST.includes(a.status)).length,
    lists: {
      today: sorted.filter(a => a.date === day),
      upcoming: sorted.filter(a => a.date > day && !LOST.includes(a.status)),
      pending: sorted.filter(a => a.status === 'PENDING'),
    },
    nextUp,
  };
}

const tabs = [['today', 'Today'], ['upcoming', 'Upcoming'], ['pending', 'Pending']];
const emptyText = {today: 'Nothing is scheduled on the selected day.', upcoming: 'No upcoming appointments in the next two weeks.', pending: 'No pending appointments in this window.'};

export function Overview({branch, day, data, onCalendar, onUpcoming, onDay, onPatients, onBook, onNewPatient}) {
  const sched = useSchedule(branch, day);
  const [tab, setTab] = useState('today');
  const m = useMemo(() => (sched.items ? summarize(sched.items, day) : null), [sched.items, day]);
  const rows = m ? m.lists[tab].slice(0, 6) : [];
  const skeleton = <div className="chart-skeleton" role="status" aria-label="Loading"/>;
  return (
    <div className="overview">
      <div className="card stat ov-a">
        <div className="stat-top"><span className="stat-label">Appointments</span><button className="pill-link" onClick={onCalendar}>View</button></div>
        <strong className="stat-value"><CountUp value={data.today}/></strong>
        <small>{fullDate(day)} · {data.today === 1 ? 'appointment' : 'appointments'} on the schedule</small>
        <div className="chart-block">
          {m ? <BarChart labels={m.weekLabels} titles={m.weekTitles} booked={m.booked} pending={m.pending}/> : sched.error ? <p className="chart-note">{sched.error.message}</p> : skeleton}
        </div>
        <div className="legend"><span><i className="key booked"/>Booked</span><span><i className="key pending"/>Pending</span><em>Next 7 days</em></div>
      </div>

      <div className="card stat ov-b1">
        <div className="stat-top"><span className="stat-label">Patients</span><button className="pill-link" onClick={onPatients}>View</button></div>
        <strong className="stat-value"><CountUp value={data.patients}/></strong>
        <small>Patients in this branch</small>
      </div>

      <div className="card stat ov-b2">
        <div className="stat-top"><span className="stat-label">Pending</span></div>
        <strong className="stat-value"><CountUp value={data.pending}/></strong>
        <small>Pending appointments · all dates</small>
      </div>

      <div className="card ov-wide">
        <section className="panel">
          <div className="stat-top"><span className="stat-label">Last 14 days</span></div>
          <strong className="stat-value"><CountUp value={m ? m.pastTotal : '–'}/></strong>
          <small>Appointments before the selected day</small>
          <div className="progress-list">
            <div className="progress-row">
              <span className="stat-icon"><Duo name="checkCircle" size={24}/></span>
              <div><div className="progress-top"><span>Completed</span><b><CountUp value={m ? m.completed : '–'}/></b></div><Progress label="Completed" value={m && m.pastTotal ? m.completed / m.pastTotal : 0}/></div>
            </div>
            <div className="progress-row">
              <span className="stat-icon teal"><Duo name="crossCircle" size={24}/></span>
              <div><div className="progress-top"><span>Cancelled or no-show</span><b><CountUp value={m ? m.lost : '–'}/></b></div><Progress tone="teal" label="Cancelled or no-show" value={m && m.pastTotal ? m.lost / m.pastTotal : 0}/></div>
            </div>
          </div>
        </section>
        <section className="panel">
          <div className="stat-top"><span className="stat-label">Upcoming</span><button className="pill-link" onClick={onUpcoming}>View</button></div>
          <strong className="stat-value"><CountUp value={data.upcoming}/></strong>
          <small>Appointments after selected day</small>
          <div className="next-up">
            <span className="stat-label">Next up</span>
            <div className="avatars">{m && m.nextUp.length ? m.nextUp.map(a => <span key={a.id} title={a.patientName}><Avatar name={a.patientName}/></span>) : <small>{m ? 'No one is waiting.' : ' '}</small>}</div>
          </div>
          <button onClick={onBook}><Icon name="calendarPlus" size={16}/>New appointment</button>
          <button className="soft" onClick={onNewPatient}><Icon name="userPlus" size={16}/>New patient</button>
        </section>
      </div>

      <div className="card ov-chart">
        <div className="card-head row">
          <h2>Appointment volume</h2>
          <span className="legend-inline"><i className="key line"/>Past days<i className="key dotted"/>Scheduled</span>
        </div>
        {m ? <LineChart labels={m.spanLabels} titles={m.spanTitles} values={m.volume} split={BEFORE}/> : sched.error ? <p className="chart-note">{sched.error.message}</p> : skeleton}
        <small className="chart-foot">Appointments per day, 14 days before to 15 days after the selected day. Cancelled and no-show are not counted.{sched.truncated ? ` Showing the first ${PAGE_SIZE * MAX_PAGES} appointments in this window.` : ''}</small>
      </div>

      <div className="card ov-table">
        <Segmented className="tabs" active={tab} role="group" aria-label="Appointments">
          {tabs.map(([id, name]) => <button key={id} aria-pressed={tab === id} onClick={() => setTab(id)}>{name}</button>)}
        </Segmented>
        {m ? (rows.length ? (
          <div className="table-wrap flush"><table><tbody>
            {rows.map(a => (
              <tr key={a.id}>
                <td><strong>{a.time.slice(0, 5)}</strong></td>
                <td><button className="text-button" onClick={() => onDay(a.date)}>{a.patientName}</button></td>
                <td>{relative(a.date)}</td>
                <td><Badge value={a.status}/></td>
              </tr>
            ))}
          </tbody></table></div>
        ) : <p className="chart-note">{emptyText[tab]}</p>) : sched.error ? <p className="chart-note">{sched.error.message}</p> : skeleton}
        <button className="text-button more" onClick={onCalendar}>View all appointments<Icon name="chevronRight" size={15}/></button>
      </div>
    </div>
  );
}
