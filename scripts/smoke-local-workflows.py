#!/usr/bin/env python3
# Only talks to loopback ports 18080 and 18025; never point these at production.
import urllib.request, urllib.error, http.cookiejar, json, base64, struct, hmac, hashlib, time, re, datetime, pathlib, argparse
parser=argparse.ArgumentParser(description='Destructive synthetic-data smoke test against a NEW isolated local database only.')
parser.add_argument('--accounts', required=True, help='Private JSON file with admin, clinician, patient and password fields')
args=parser.parse_args()
C=json.loads(pathlib.Path(args.accounts).read_text())
BASE='http://127.0.0.1:18080'
class Client:
 def __init__(self): self.op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())); self.token=None
 def req(self,path,method='GET',data=None,raw=None,content=None,expected=200):
  headers={}
  if self.token: headers['Authorization']='Bearer '+self.token
  if method!='GET' and path.startswith('/api/staff'):
   headers['X-XSRF-TOKEN']=self.req('/api/staff-auth/csrf')['token']
  if data is not None: raw=json.dumps(data).encode();content='application/json'
  if content: headers['Content-Type']=content
  try: r=self.op.open(urllib.request.Request(BASE+path,data=raw,method=method,headers=headers));body=r.read();status=r.status;typ=r.headers.get('Content-Type','')
  except urllib.error.HTTPError as e: body=e.read();status=e.code;typ=e.headers.get('Content-Type','')
  assert status==expected,(path,status,body[:250])
  return json.loads(body) if 'json' in typ else body
 def stafflogin(self,email):
  payload={'email':email,'password':C['password']}
  s=self.req('/api/staff-auth/mfa/setup','POST',payload)['data']['secret']
  counter=int(time.time())//30;digest=hmac.new(base64.b32decode(s),struct.pack('>Q',counter),hashlib.sha1).digest();off=digest[-1]&15
  otp=str((struct.unpack('>I',digest[off:off+4])[0]&0x7fffffff)%1000000).zfill(6)
  self.req('/api/staff-auth/login','POST',dict(payload,otp=otp))
  return self.req('/api/staff/me')['data']
def mailcode(email):
 for attempt in range(25):
  data=json.load(urllib.request.urlopen('http://127.0.0.1:18025/api/v1/messages'))
  for m in data['messages']:
   if any(t['Address']==email for t in m['To']):
    message=json.load(urllib.request.urlopen('http://127.0.0.1:18025/api/v1/message/'+m['ID']))
    code=re.search(r'\b\d{6}\b', message.get('Text','')+' '+message.get('HTML',''))
    if code:return code.group()
  time.sleep(1)
 raise AssertionError('No local setup email for '+email)
admin=Client(); assert admin.stafflogin(C['admin'])['role']=='ADMIN'; print('PASS first administrator and MFA cookie login')
admin.req('/api/staff/members','POST',{'fullName':'Synthetic launch clinician','email':C['clinician'],'phone':'999000102','branch':'MARINA','staffRole':'CLINICIAN'})
pid=admin.req('/api/staff/patients?branch=MARINA','POST',{'fullName':'Synthetic launch patient','email':C['patient'],'phone':'999000103'})['data']['id']
for email in [C['clinician'],C['patient']]:
 Client().req('/api/auth/reset-password','POST',{'email':email,'otp':mailcode(email),'newPassword':C['password']})
print('PASS clinician/patient setup through delivered local email codes')
clinician=Client(); assert clinician.stafflogin(C['clinician'])['memberships'][0]['role']=='CLINICIAN'
patient=Client();patient.token=patient.req('/api/auth/login','POST',{'email':C['patient'],'password':C['password']})['data']['accessToken']
print('PASS separate clinician MFA and patient login')
day=(datetime.date.today()+datetime.timedelta(days=3)).isoformat()
a=patient.req('/api/appointments','POST',{'appointmentDate':day,'appointmentTime':'10:30:00','branch':'MARINA','note':'Synthetic launch test only','claimGiftVoucher':True})['data']
assert a['giftVoucherBooking'] is True
items=admin.req('/api/staff/appointments?branch=MARINA&from='+day+'&to='+day)['data']['items'];assert any(x['id']==a['id'] for x in items)
assert patient.req('/api/user/profile')['data']['giftVoucherClaimed'] is True
print('PASS voucher booking visible in staff dashboard API and profile claim persisted')
assert patient.req('/api/reports')['data']==[]
boundary='BPSyntheticBoundary';pdf=b'%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n'
fields={'title':'Synthetic verification report','reportDate':datetime.date.today().isoformat()};parts=[]
for k,v in fields.items(): parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode())
parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="synthetic.pdf"\r\nContent-Type: application/pdf\r\n\r\n'.encode()+pdf+b'\r\n')
parts.append(f'--{boundary}--\r\n'.encode())
rid=clinician.req(f'/api/staff/patients/{pid}/reports?branch=MARINA','POST',raw=b''.join(parts),content='multipart/form-data; boundary='+boundary)['data']
assert patient.req('/api/reports')['data'][0]['id']==rid
assert patient.req(f'/api/reports/{rid}/download')==pdf
Client().req(f'/api/reports/{rid}/download',expected=401)
clinician.req(f'/api/staff/patients/{pid}/reports/{rid}?branch=MARINA','DELETE')
assert patient.req('/api/reports')['data']==[]
patient.req(f'/api/reports/{rid}/download',expected=404)
print('PASS report upload, owner download, anonymous denial, withdrawal and empty list')
print('ALL EXECUTED HTTP SMOKE CHECKS PASSED — isolated local database only')
