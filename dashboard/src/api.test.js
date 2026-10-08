import test from 'node:test';
import assert from 'node:assert/strict';
import {createApi, ApiError, params} from './api.js';
const response = (status, body) => new Response(JSON.stringify(body), { status, headers: {'Content-Type': 'application/json'} });
test('50 concurrent unauthorized requests share one refresh and retry once', async () => {
  let refreshed = false, rotations = 0;
  const client = createApi(async (path) => {
    if(path.endsWith('/csrf')) return response(200,{token:'csrf-test'});
    if(path.endsWith('/refresh')) { rotations++; await new Promise(r=>setTimeout(r,10));refreshed=true;return response(200,{success:true}); }
    return refreshed?response(200,{success:true,data:{ok:true}}):response(401,{success:false});
  });
  const results=await Promise.all(Array.from({length:50},()=>client.request('/api/staff/me')));
  assert.equal(rotations,1);assert.ok(results.every(x=>x.ok));
});
test('mutations send CSRF header and never bearer credentials', async()=>{
  let seen;
  const client=createApi(async(path, options)=>{
    if(path.endsWith('/csrf'))return response(200,{token:'csrf-value'});
    seen=options;return response(200,{success:true,data:{id:1}});
  });
  await client.request('/api/staff/patients',{method:'POST',body:'{}'});
  assert.equal(seen.headers['X-XSRF-TOKEN'],'csrf-value');assert.equal(seen.headers.Authorization,undefined);assert.equal(seen.credentials,'same-origin');
});
test('permission/conflict failures preserve status and request identity',async()=>{
  const client=createApi(async()=>new Response(JSON.stringify({success:false,message:'Record changed'}),{status:409,headers:{'X-Request-Id':'safe-request'}}));
  await assert.rejects(client.request('/api/staff/patients'),e=>e instanceof ApiError&&e.status===409&&e.requestId==='safe-request');
});
test('query values are encoded and missing filters omitted',()=>assert.equal(params({query:'a&b',page:0,missing:undefined}),'query=a%26b&page=0'));

test('sequential writes obtain fresh CSRF challenges after authentication changes',async()=>{
  let count=0;const seen=[];
  const client=createApi(async(path,options)=>{
    if(path.endsWith('/csrf'))return response(200,{token:'csrf-'+(++count)});
    seen.push(options.headers['X-XSRF-TOKEN']);return response(200,{success:true});
  });
  await client.request('/api/staff-auth/login',{method:'POST',body:'{}'});
  await client.request('/api/staff/patients',{method:'POST',body:'{}'});
  assert.deepEqual(seen,['csrf-1','csrf-2']);
});

test('logout refreshes an expired access cookie before revoking the session',async()=>{
 let fresh=false,revoked=false,refreshes=0;
 const client=createApi(async(path)=>{
  if(path.endsWith('/csrf'))return response(200,{token:'current'});
  if(path.endsWith('/refresh')){fresh=true;refreshes++;return response(200,{success:true});}
  if(path.endsWith('/logout')){if(!fresh)return response(401,{success:false});revoked=true;return response(200,{success:true});}
  throw Error('Unexpected route');
 });
 await client.request('/api/staff-auth/logout',{method:'POST'});
 assert.equal(refreshes,1);assert.equal(revoked,true);
});

test('multipart uploads preserve FormData and use CSRF without JSON content type', async () => {
  let sent;
  const client = createApi(async (path, options) => {
    if(path.endsWith('/csrf')) return new Response(JSON.stringify({token:'csrf-test'}));
    sent=options;
    return new Response(JSON.stringify({success:true,data:42}));
  });
  const body=new FormData();body.set('title','Synthetic report');
  assert.equal(await client.request('/api/staff/patients/1/reports',{method:'POST',body}),42);
  assert.equal(sent.body,body);
  assert.equal(sent.headers['Content-Type'],undefined);
  assert.equal(sent.headers['X-XSRF-TOKEN'],'csrf-test');
});

test('authenticated download returns a blob and preserves JSON errors', async () => {
  const client=createApi(async path=>path.endsWith('/missing')
    ? new Response(JSON.stringify({message:'Report not found'}),{status:404})
    : new Response('%PDF-test',{headers:{'Content-Type':'application/pdf'}}));
  const blob=await client.request('/api/staff/reports/1',{responseType:'blob'});
  assert.equal(await blob.text(),'%PDF-test');
  await assert.rejects(client.request('/api/staff/reports/missing',{responseType:'blob'}),/Report not found/);
});
