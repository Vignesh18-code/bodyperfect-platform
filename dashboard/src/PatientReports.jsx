import React, {useEffect, useState} from 'react';
import {api, params} from './api.js';
import {Notice} from './ui.jsx';

export function PatientReports({branch, patient}) {
  const [reports,setReports]=useState([]), [error,setError]=useState(), [loading,setLoading]=useState(true), [busy,setBusy]=useState(false), [message,setMessage]=useState('');
  const endpoint=(suffix='')=>`/api/staff/patients/${patient}/reports${suffix}?${params({branch})}`;
  async function load(){setReports(await api.request(endpoint()));}
  useEffect(()=>{let active=true;api.request(endpoint()).then(r=>{if(active)setReports(r);}).catch(e=>{if(active)setError(e);}).finally(()=>{if(active)setLoading(false);});return()=>{active=false;};},[branch,patient]);
  async function upload(e){
    e.preventDefault(); if(busy)return;
    const form=e.currentTarget, body=new FormData(form), file=body.get('file');
    if(!file?.size || file.size>5*1024*1024 || file.type!=='application/pdf'){setError(new Error('Choose a PDF up to 5 MB.'));return;}
    setBusy(true);setError(null);setMessage('');
    try{await api.request(endpoint(),{method:'POST',body});form.reset();setMessage('Report published to the client’s app.');await load();}catch(e){setError(e);}finally{setBusy(false);}
  }
  async function download(report){
    setBusy(true);setError(null);
    try{const blob=await api.request(endpoint(`/${report.id}/download`),{responseType:'blob'});const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download=`bodyperfect-report-${report.id}.pdf`;a.click();setTimeout(()=>URL.revokeObjectURL(url),10000);}catch(e){setError(e);}finally{setBusy(false);}
  }
  async function withdraw(report){
    if(!window.confirm(`Withdraw “${report.title}”? The client will no longer be able to download it. The stored PDF will be removed; the audit record will remain.`))return;
    setBusy(true);setError(null);setMessage('');
    try{await api.request(endpoint(`/${report.id}`),{method:'DELETE'});await load();setMessage('Report withdrawn.');}catch(e){setError(e);}finally{setBusy(false);}
  }
  return <section className="patient-reports"><h3>Client reports</h3><p className="muted">Publish reviewed PDF reports to this client. Up to 5 MB per PDF. Check the patient and document before publishing.</p><Notice error={error}/>{message&&<p role="status">{message}</p>}
    {loading?<p role="status">Loading reports…</p>:reports.map(report=><article className="clinical-card" key={report.id}><strong>{report.title}</strong><small>{report.reportDate} · PDF · {Math.ceil(report.sizeBytes/1024)} KB</small><div className="form-actions"><button className="secondary" disabled={busy} onClick={()=>download(report)}>Download PDF</button><button className="secondary" disabled={busy} onClick={()=>withdraw(report)}>Withdraw</button></div></article>)}
    {!loading&&!reports.length&&!error&&<p className="muted">No reports shared yet. The app hides the reports section until you publish one.</p>}
    <form onSubmit={upload}><label>Report title<input name="title" maxLength={150} placeholder="e.g. Consultation summary" required/></label><label>Report date<input name="reportDate" type="date" required/></label><label>PDF document<input name="file" type="file" accept="application/pdf,.pdf" required/></label><button disabled={busy||loading}>{busy?'Please wait…':'Publish report to client'}</button></form>
  </section>;
}
