import {PatientReports} from './PatientReports.jsx';
import {PrivacyQueue} from './PrivacyQueue.jsx';
import React, { useEffect, useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { api, params } from './api.js';
import './styles.css';
import {SupportInbox} from './SupportInbox.jsx';
import {FollowUps} from './FollowUps.jsx';
import {Templates,PatientPlans} from './Clinical.jsx';
import {BookingForm,AppointmentActions,ScheduleSettings} from './Scheduling.jsx';
import {Icon,Duo,Avatar,Badge,Notice,Empty,human} from './ui.jsx';
import {Overview,addDays} from './Overview.jsx';
import './workspace.css';
import './motion.css';

const branchNames = { BURJUMAN: 'BurJuman', MARINA: 'Marina' };
const today = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`; };
const navIcons = { overview:'dashboard', patients:'users', calendar:'calendar', followups:'checks', support:'message', templates:'file', staff:'shield', audit:'history', settings:'sliders' };
const navGroups = [['Workspace',['overview','patients','calendar','followups','support']],['Clinical',['templates']],['Administration',['staff','audit','settings']]];
const viewHint = {
  overview:'A practical view of your branch and the work ahead.',
  patients:'Find a patient, review their details, and keep information current.',
  calendar:'Review the schedule without losing the context.',
  staff:'Individual accounts. Deliberate access.',
  support:'Respond to patients, coordinate care, and keep every conversation in one place.',
  followups:'Assign, track, and resolve patient follow-ups.',
  templates:'Author, review, and version clinic treatment instructions.',
  settings:'Configure services, resources, and working hours.',
  audit:'A traceable record of staff actions in this branch.',
};
const viewTitle = { overview:'Operational summary', patients:'Patient directory', calendar:'Appointment list', staff:'Branch team', support:'Patient conversations', followups:'Branch follow-ups', templates:'Clinical library', settings:'Resource configuration', audit:'Recent activity' };
function Dialog({title,onClose,children,wide}) {
  const ref=useRef(null);
  useEffect(()=>{const el=ref.current;el.showModal();return()=>el.close();},[]);
  return <dialog ref={ref} className={wide?'wide':undefined} onCancel={onClose} aria-labelledby="dialog-title"><div className="dialog-head"><h2 id="dialog-title">{title}</h2><button className="icon" aria-label="Close dialog" onClick={onClose}><Icon name="x"/></button></div><div className="dialog-body">{children}</div></dialog>;
}
function Field({label,...props}) { return <label>{label}<input {...props}/></label>; }
function Pager({data,page,setPage}) { return <div className="pager"><span>Page {page+1}</span><button className="secondary" disabled={page===0} onClick={()=>setPage(page-1)}><Icon name="chevronLeft" size={16}/>Previous</button><button className="secondary" disabled={!data?.hasNext} onClick={()=>setPage(page+1)}>Next<Icon name="chevronRight" size={16}/></button></div>; }
function Login({onLogin}) {
  const [error,setError]=useState(),[busy,setBusy]=useState(false),[recovery,setRecovery]=useState(false),[sent,setSent]=useState(false),[mfa,setMfa]=useState(false),[setupKey,setSetupKey]=useState('');
  async function submit(e) {
    e.preventDefault();setError(null);setBusy(true);const fields=Object.fromEntries(new FormData(e.target));
    try {
      if(recovery) {
        const route=sent?'/api/auth/reset-password':'/api/auth/forgot-password';
        await api.request(route,{method:'POST',body:JSON.stringify(fields)});
        if(sent){setRecovery(false);setSent(false);}else setSent(true);
      } else {await api.request('/api/staff-auth/login',{method:'POST',body:JSON.stringify(fields)});await onLogin();}
    } catch(err){
      if(err.message==='MFA_SETUP_REQUIRED'){
        try{const setup=await api.request('/api/staff-auth/mfa/setup',{method:'POST',body:JSON.stringify(fields)});setSetupKey(setup.secret);setMfa(true);}catch(e){setError(e);}
      }else if(err.message==='MFA_REQUIRED'){setMfa(true);setSetupKey('');}
      else setError(err);
    }finally{setBusy(false);}
  }
  return <div className="login-layout">
    <section className="login-brand">
      <div className="brand"><span className="mark">b.</span><span className="brand-name">BODY PERFECT</span></div>
      <div><span className="eyebrow">CLINIC OPERATIONS</span><h1>A clear view.<br/><em>A considered next step.</em></h1><p>Your workspace for patients, appointments and coordinated care.</p></div>
      <small className="login-foot"><Icon name="lock" size={14}/>For authorized clinic staff</small>
    </section>
    <main className="login-form"><div className="form-wrap">
      <span className="eyebrow">WELCOME BACK</span>
      <h2>{recovery?'Set up your password':'Sign in to your workspace'}</h2>
      <p className="muted">{recovery?'Use your clinic email to request a reset code.':'Use your individual clinic account.'}</p>
      <Notice error={error}/>
      {mfa&&<p>Enter the six-digit code from your authenticator app.</p>}
      {setupKey&&<p>Add a time-based account named BodyPerfect to your authenticator using this setup key: <code>{setupKey}</code>. Keep it private; it will not be shown after enrollment.</p>}
      <form onSubmit={submit}>
        {mfa&&!recovery&&<Field label="Authenticator code" name="otp" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" required/>}
        <Field label="Email address" name="email" type="email" autoComplete="username" required/>
        {recovery?(sent&&<><Field label="Six-digit email code" name="otp" inputMode="numeric" pattern="[0-9]{6}" required/><Field label="New password" name="newPassword" type="password" autoComplete="new-password" minLength={8} maxLength={72} required/><small>Include uppercase, lowercase, a number and a special character (@$!%*?&).</small></>):<Field label="Password" name="password" type="password" autoComplete="current-password" required/>}
        <button disabled={busy}>{busy?'Please wait…':recovery?(sent?'Set password':'Request code'):'Sign in'}</button>
      </form>
      <button className="text-button" onClick={()=>{setRecovery(!recovery);setSent(false);setError(null);setMfa(false);setSetupKey('');}}>{recovery?'Back to sign in':'First time here or forgot your password?'}</button>
    </div></main>
  </div>;
}
function PatientForm({patient,branch,onDone,onClose}) {
  const [error,setError]=useState(),[busy,setBusy]=useState(false);
  async function save(e){e.preventDefault();setBusy(true);setError(null);const body=Object.fromEntries(new FormData(e.target));if(patient)body.version=patient.version;
    try{await api.request(`/api/staff/patients${patient?'/'+patient.id:''}?${params({branch})}`,{method:patient?'PUT':'POST',body:JSON.stringify(body)});onDone();}catch(err){setError(err);}finally{setBusy(false);}}
  return <Dialog title={patient?'Edit patient':'New patient'} onClose={onClose}><Notice error={error}/><form onSubmit={save}><Field label="Full name" name="fullName" defaultValue={patient?.fullName} minLength={2} maxLength={100} required/>{!patient&&<Field label="Email address" type="email" name="email" required/>}<Field label="Phone · digits only" name="phone" inputMode="tel" pattern="[0-9]{9,15}" defaultValue={patient?.phone} required/><p className="muted">Record belongs to {branchNames[branch]}. Confirm contact details with the patient. They can use Forgot password in the patient app to request a setup code and choose their password.</p><div className="form-actions"><button type="button" className="secondary" onClick={onClose}>Cancel</button><button disabled={busy}>{busy?'Saving…':'Save patient'}</button></div></form></Dialog>;
}
function StaffForm({branch,onClose,onDone}) {
  const [error,setError]=useState(),[busy,setBusy]=useState(false);
  async function submit(e){e.preventDefault();setBusy(true);try{await api.request('/api/staff/members',{method:'POST',body:JSON.stringify({...Object.fromEntries(new FormData(e.target)),branch})});onDone();}catch(err){setError(err);}finally{setBusy(false);}}
  return <Dialog title="Invite staff member" onClose={onClose}><Notice error={error}/><form onSubmit={submit}><Field label="Full name" name="fullName" required maxLength={100}/><Field label="Clinic email" name="email" type="email" required/><Field label="Phone · digits only" name="phone" pattern="[0-9]{9,15}" required/><label>Branch role<select name="staffRole"><option value="RECEPTION">Reception</option><option value="CLINICIAN">Clinician</option><option value="BRANCH_MANAGER">Branch manager</option></select></label><p className="muted">A password setup request will be sent to the supplied email. No shared password is created.</p><div className="form-actions"><button disabled={busy}>{busy?'Creating…':'Create staff account'}</button></div></form></Dialog>;
}
function AppointmentsTable({items,branch,clinical,onChanged,onReschedule}) { return items?.length?<div className="table-wrap"><table><thead><tr><th>Time</th><th>Patient</th><th>Status</th><th>Reference</th>{onChanged&&<th>Actions</th>}</tr></thead><tbody>{items.map(a=><tr key={a.id}><td className="when"><strong>{a.time.slice(0,5)}</strong><small>{a.date}</small></td><td><div className="person"><Avatar name={a.patientName} size="sm"/><strong>{a.patientName}</strong></div></td><td><Badge value={a.status}/></td><td><span className="ref">AP-{a.id}</span></td>{onChanged&&<td><AppointmentActions appointment={a} branch={branch} clinical={clinical} onChanged={onChanged} onReschedule={onReschedule}/></td>}</tr>)}</tbody></table></div>:<Empty icon="calendar">No appointments in this date range. Change the dates to view another day.</Empty>; }
function Workspace({me,onLogout}) {
  const initial=new URLSearchParams(location.search);
  const [view,setView]=useState(initial.get('view')||'overview'),[branch,setBranch]=useState(me.memberships.some(m=>m.branch===initial.get('branch'))?initial.get('branch'):me.memberships[0]?.branch||''),[query,setQuery]=useState(initial.get('query')||''),[debounced,setDebounced]=useState(query),[page,setPage]=useState(0),[day,setDay]=useState(today()),[to,setTo]=useState(today()),[data,setData]=useState(),[error,setError]=useState(),[loading,setLoading]=useState(true),[refresh,setRefresh]=useState(0),[dialog,setDialog]=useState(),[selected,setSelected]=useState(),[detail,setDetail]=useState(),[detailError,setDetailError]=useState(),[rescheduling,setRescheduling]=useState();
  const [navToggled,setNavToggled]=useState(false);
  const role=me.memberships.find(m=>m.branch===branch)?.role, manager=me.role==='ADMIN'||role==='BRANCH_MANAGER';
  const tabs=[['overview','Overview','01'],['patients','Patients','02'],['calendar','Appointments','03'],['followups','Follow-ups','04'],['support','Patient support','05'],...(role==='CLINICIAN'?[['templates','Clinical templates','04']]:[]),...(manager?[['staff','Staff & access','04'],['audit','Audit history','05'],['settings','Scheduling setup','06']]:[])];
  useEffect(()=>{const timer=setTimeout(()=>{setDebounced(query);setPage(0);},300);return()=>clearTimeout(timer);},[query]);
  useEffect(()=>{history.replaceState(null,'','?'+params({view,branch,query:query||undefined}));},[view,branch,query]);
  useEffect(()=>{setSelected(null);setPage(0);},[branch,view]);
  useEffect(()=>{if(!branch||['settings','templates','followups','support'].includes(view)){setLoading(false);setError(null);return;}const abort=new AbortController();setLoading(true);setError(null);setData(undefined);
    const routes={overview:`/overview?${params({branch,day})}`,patients:`/patients?${params({branch,query:debounced,page})}`,calendar:`/appointments?${params({branch,from:day,to,page})}`,staff:`/members?${params({branch})}`,audit:`/audit?${params({branch,page})}`};
    const route=routes[view];if(!route){setView('overview');return;}
    api.request('/api/staff'+route,{signal:abort.signal}).then(setData).catch(e=>{if(e.name!=='AbortError')setError(e);}).finally(()=>{if(!abort.signal.aborted)setLoading(false);});return()=>abort.abort();
  },[view,branch,debounced,page,day,to,refresh]);
  useEffect(()=>{if(!selected)return;let active=true;setDetail(null);setDetailError(null);api.request(`/api/staff/appointments?${params({branch,from:day,to,patientId:selected.id})}`).then(d=>{if(active)setDetail(d);}).catch(e=>{if(active)setDetailError(e);});return()=>{active=false;};},[selected,branch,day,to]);
  function done(){setDialog(null);setSelected(null);setRefresh(x=>x+1);}
  async function changeAccess(person){if(!window.confirm(`${person.active?'Deactivate':'Activate'} ${person.fullName}'s ${branchNames[branch]} access? Existing sessions will be revoked.`))return;try{await api.request('/api/staff/members/'+person.id,{method:'PUT',body:JSON.stringify({branch,staffRole:person.staffRole,active:!person.active})});setRefresh(x=>x+1);}catch(e){setError(e);}}
  if(!branch)return <main className="form-wrap"><h1>No branch access assigned</h1><p>Ask your clinic administrator to assign a branch before opening patient records.</p><button onClick={onLogout}>Sign out</button></main>;
  const pageName=tabs.find(t=>t[0]===view)?.[1];
  const navToggle=()=>setNavToggled(x=>!x);
  const pick=id=>{setView(id);if(window.matchMedia('(max-width:1199px)').matches)setNavToggled(false);};
  const bookNew=()=>{setRescheduling(null);setDialog('booking');};
  const roleLabel=human(me.role==='ADMIN'?'ADMIN':role);
  const filters=<div className="filters">{view==='patients'&&<div className="search"><Icon name="search" size={16}/><input aria-label="Search patients" placeholder="Search name, email or phone" value={query} onChange={e=>setQuery(e.target.value)}/></div>}{['overview','calendar'].includes(view)&&<input aria-label="Start date" type="date" value={day} onChange={e=>{setDay(e.target.value);if(e.target.value>to)setTo(e.target.value);}}/>}{view==='calendar'&&<input aria-label="End date" type="date" value={to} min={day} onChange={e=>setTo(e.target.value)}/>}<button className={`secondary${loading?' busy':''}`} onClick={()=>setRefresh(x=>x+1)}><Icon name="refresh" size={15}/>Refresh</button></div>;
  return <div className={`workspace view-${view}${navToggled?' nav-toggled':''}`}>
    <aside className="sidebar">
      <div className="sidebar-header">
        <a className="brand" href="?view=overview"><span className="mark">b.</span><h4 className="logo-title">Body Perfect</h4></a>
        <button className="sidebar-toggle" aria-label="Toggle navigation" aria-expanded={!navToggled} onClick={navToggle}><Icon name="chevronLeft" size={14}/></button>
      </div>
      <nav aria-label="Main navigation">{navGroups.map(([label,ids])=>{const items=tabs.filter(t=>ids.includes(t[0]));return items.length>0&&<div className="nav-group" key={label}><div className="nav-label"><span>{label}</span></div>{items.map(([id,name])=><div className={`nav-item${view===id?' active':''}`} key={id}><button aria-current={view===id?'page':undefined} title={name} onClick={()=>pick(id)}><Duo name={navIcons[id]} size={20}/><span className="item-name">{name}</span></button></div>)}</div>;})}</nav>
    </aside>
    <div className="nav-scrim" onClick={()=>setNavToggled(false)}/>
    <div className="main-column">
      <header className="topbar">
        <div className="topbar-left">
          <button className="icon nav-burger" aria-label="Open navigation" onClick={navToggle}><Icon name="menu"/></button>
          <label className="nav-search"><Icon name="search" size={16}/><input aria-label="Search patients" placeholder="Search patients…" value={query} onChange={e=>{setQuery(e.target.value);setView('patients');}}/></label>
        </div>
        <div className="topbar-right">
          <span className="today-chip">{new Date().toLocaleDateString('en-GB',{weekday:'long',day:'numeric',month:'long',year:'numeric'})}</span>
          <label className="branch-select"><Icon name="pin" size={15}/><span>Branch</span><select value={branch} onChange={e=>setBranch(e.target.value)}>{me.memberships.map(m=><option key={m.branch} value={m.branch}>{branchNames[m.branch]}</option>)}</select></label>
          <button className="icon round" title="Patient support" aria-label="Patient support" onClick={()=>setView('support')}><Duo name="mail" size={20}/></button>
          <div className="user-chip"><Avatar name={me.fullName}/><div><strong>{me.fullName}</strong><small>{roleLabel}</small></div></div>
          <button className="icon" title="Sign out" aria-label="Sign out" onClick={onLogout}><Icon name="logout"/></button>
        </div>
      </header>
      <main>
        {view!=='overview'&&<div className="page-banner"><div className="banner-row" key={view}><div><h1>{pageName}</h1><p>{viewHint[view]||viewHint.audit}</p></div><div className="banner-actions">{view==='calendar'&&<button className="soft" onClick={bookNew}><Icon name="plus" size={16}/>New appointment</button>}{view==='patients'&&<button className="soft" onClick={()=>setDialog('patient')}><Icon name="plus" size={16}/>New patient</button>}{view==='staff'&&me.role==='ADMIN'&&<button className="soft" onClick={()=>setDialog('staff')}><Icon name="plus" size={16}/>Invite staff</button>}</div></div></div>}
        <div className={`content-inner${view==='overview'?'':' overlap'}`}>
          {view==='overview'&&<div className="page-head"><div><h1>The day, at a glance.</h1><span className="page-sub">{branchNames[branch]} · Clinic operations</span></div>{filters}</div>}
          <Notice error={error}/>
          {error?.status===401&&<button onClick={onLogout}>Return to sign in</button>}
          <section className={`surface${view==='overview'?' flat':''}`}>
            {view!=='overview'&&<div className="toolbar"><h2>{viewTitle[view]||viewTitle.audit}</h2>{filters}</div>}
            {loading?<div className="loading" role="status"><span>Loading branch records…</span><div/><div/><div/><div/><div/></div>:!error&&<>
              {view==='overview'&&data&&<Overview branch={branch} day={day} data={data} onCalendar={()=>{setTo(day);setView('calendar');}} onUpcoming={()=>{setTo(addDays(day,30));setView('calendar');}} onDay={date=>{setDay(date);setTo(date);setView('calendar');}} onPatients={()=>setView('patients')} onBook={bookNew} onNewPatient={()=>setDialog('patient')}/>}
              {view==='patients'&&(data?.items?.length?<div className="table-wrap"><table><thead><tr><th>Patient</th><th>Contact</th><th>Account</th><th>Action</th></tr></thead><tbody>{data.items.map(p=><tr key={p.id}><td><div className="person"><Avatar name={p.fullName}/><div><strong>{p.fullName}</strong><small>BP-{p.id}</small></div></div></td><td>{p.email}<small>{p.phone}</small></td><td><Badge value={p.status}/></td><td><button className="text-button" onClick={()=>setSelected(p)}>Open record<Icon name="chevronRight" size={15}/></button></td></tr>)}</tbody></table></div>:<Empty icon="users">{query?'No patients match this search. Try a name, email or phone.':'No patients are associated with this branch yet. Add a patient to get started.'}</Empty>)}
              {view==='calendar'&&<AppointmentsTable items={data?.items} branch={branch} clinical={role==='CLINICIAN'} onChanged={()=>setRefresh(x=>x+1)} onReschedule={a=>{setRescheduling(a);setDialog('booking');}}/>}
              {view==='support'&&<><SupportInbox key={`${branch}-${refresh}`} branch={branch}/>{me.role==='ADMIN'&&<PrivacyQueue/>}</>}
              {view==='followups'&&<FollowUps key={`${branch}-${refresh}`} branch={branch}/>}
              {view==='templates'&&<Templates key={`${branch}-${refresh}`} branch={branch}/>}
              {view==='settings'&&<ScheduleSettings key={`${branch}-${refresh}`} branch={branch}/>}
              {view==='staff'&&(data?.length?<div className="table-wrap"><table><thead><tr><th>Staff member</th><th>Branch role</th><th>Access</th><th>Action</th></tr></thead><tbody>{data.map(s=><tr key={s.id}><td><div className="person"><Avatar name={s.fullName}/><div><strong>{s.fullName}</strong><small>{s.email}</small></div></div></td><td>{human(s.staffRole)}</td><td><Badge value={s.active?'ACTIVE':'INACTIVE'}/></td><td>{me.role==='ADMIN'&&<button className={`text-button${s.active?' danger':''}`} onClick={()=>changeAccess(s)}>{s.active?'Deactivate':'Activate'}</button>}</td></tr>)}</tbody></table></div>:<Empty icon="shield">No staff memberships in this branch. An administrator can invite staff.</Empty>)}
              {view==='audit'&&(data?.items?.length?<div className="table-wrap"><table><thead><tr><th>Time</th><th>Action</th><th>Actor</th><th>Record</th></tr></thead><tbody>{data.items.map(a=><tr key={a.id}><td>{new Date(a.occurredAt).toLocaleString()}</td><td>{human(a.action)}<small>{a.requestId}</small></td><td>Staff #{a.actorId}</td><td>{human(a.entityType)} #{a.entityId}</td></tr>)}</tbody></table></div>:<Empty icon="history">No audit events recorded in this branch yet.</Empty>)}
              {['patients','calendar','audit'].includes(view)&&<Pager data={data} page={page} setPage={setPage}/>}
            </>}
          </section>
        </div>
      </main>
      <footer className="footer"><span>BodyPerfect · Clinic operations</span><span>Branch access is enforced by the server.</span></footer>
    </div>
    {dialog==='booking'&&<Dialog title={rescheduling?(rescheduling.resourceId?'Reschedule appointment':'Confirm appointment request'):'New appointment'} onClose={()=>setDialog(null)}><BookingForm branch={branch} appointment={rescheduling} onDone={done}/></Dialog>}
    {dialog==='patient'&&<PatientForm branch={branch} onDone={done} onClose={()=>setDialog(null)}/>}
    {dialog==='edit'&&<PatientForm patient={selected} branch={branch} onDone={done} onClose={()=>setDialog(null)}/>}
    {dialog==='staff'&&<StaffForm branch={branch} onDone={done} onClose={()=>setDialog(null)}/>}
    {selected&&!dialog&&<Dialog wide title={selected.fullName} onClose={()=>setSelected(null)}>
      <div className="patient-summary"><Avatar name={selected.fullName} size="lg"/><div className="who"><Badge value={selected.status}/><div className="contact"><span><Icon name="mail" size={15}/>{selected.email}</span><span><Icon name="phone" size={15}/>{selected.phone}</span></div></div><button className="secondary" onClick={()=>setDialog('edit')}><Icon name="edit" size={15}/>Edit details</button></div>
      {role==='CLINICIAN'&&<><PatientPlans branch={branch} patient={selected.id}/><PatientReports key={`${branch}-${selected.id}`} branch={branch} patient={selected.id}/></>}
      <h3>Appointments · {day} to {to}</h3><Notice error={detailError}/>{detail?<AppointmentsTable items={detail.items}/>:!detailError&&<p role="status">Loading appointments…</p>}
    </Dialog>}
  </div>;
}
function App(){const[me,setMe]=useState(),[checking,setChecking]=useState(true),[error,setError]=useState();async function load(){const user=await api.request('/api/staff/me');setMe(user);}useEffect(()=>{load().catch(e=>{if(e.status!==401)setError(e);}).finally(()=>setChecking(false));},[]);async function logout(){try{await api.request('/api/staff-auth/logout',{method:'POST'});}catch(e){if(e.status!==401){setError(e);return;}}api.reset();setMe(null);setError(null);}if(checking)return <main className="form-wrap" role="status">Opening your workspace…</main>;return <><Notice error={error}/>{me?<Workspace me={me} onLogout={logout}/>:<Login onLogin={load}/>}</>;}
createRoot(document.getElementById('root')).render(<App/>);
