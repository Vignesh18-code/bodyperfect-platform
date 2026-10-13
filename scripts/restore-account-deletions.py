#!/usr/bin/env python3
"""Run inside the private UAE recovery environment, with psql's PG* variables.
Export the newest closure ledger before restoring a database. Keep it encrypted in
approved backup storage. Reapply it to the isolated restored database before API
access is enabled. Never place the ledger in Git or a public filesystem.
"""
import argparse,json,os,pathlib,subprocess
os.umask(0o077)
p=argparse.ArgumentParser();p.add_argument('action',choices=['export','reapply']);p.add_argument('ledger',type=pathlib.Path);p.add_argument('--confirm-api-stopped',action='store_true');a=p.parse_args()
def sql(value):
 return 'NULL' if value is None else "'"+str(value).replace("'","''")+"'"
def execute(statement):
 r=subprocess.run(['psql','-X','-q','-A','-t','-v','ON_ERROR_STOP=1'],input=statement,text=True,capture_output=True)
 if r.returncode:raise SystemExit('Closure ledger operation failed; restored API must remain stopped. No record values were logged.')
 return r.stdout.strip()
if a.action=='export':
 data=execute("SELECT coalesce(json_agg(row_to_json(c)), '[]'::json) FROM account_closures c;")
 a.ledger.write_text(data+'\n');os.chmod(a.ledger,0o600)
 print('Closure ledger exported to protected path; encrypt before storage/transfer.')
else:
 if not a.confirm_api_stopped:raise SystemExit('Stop the restored API and use --confirm-api-stopped before replay.')
 rows=json.loads(a.ledger.read_text());statements=['BEGIN;']
 for c in rows:
  uid=int(c['patient_id']);rid=int(c['request_id']);actor=int(c['closed_by'])
  created=sql(c['original_created_at']);reason=sql(c['retention_reason']);identity=sql(c['retained_identity']);closed=sql(c['closed_at'])
  ids=[int(i) for i in c['deleted_message_ids']];ids_json=sql(json.dumps(ids))
  statements.append(f"DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM users WHERE id={uid} AND created_at={created}::timestamp AND role='PATIENT') THEN RAISE EXCEPTION 'Restored identity mismatch'; END IF; END $$;")
  # Closure requests may postdate the restored point; reconstruct their audit link.
  statements.append(f"INSERT INTO privacy_requests(id,patient_id,state,created_at,updated_at,resolution,reviewed_by) VALUES ({rid},{uid},'IN_REVIEW',{closed},{closed},'Previously approved deletion reapplied during recovery',{actor}) ON CONFLICT(id) DO NOTHING;")
  statements.append(f"DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM privacy_requests WHERE id={rid} AND patient_id={uid}) THEN RAISE EXCEPTION 'Restored request mismatch'; END IF; END $$;")
  statements.append(f"INSERT INTO account_closures(patient_id,request_id,closed_by,closed_at,original_created_at,retained_identity,retention_reason,deleted_message_ids) VALUES ({uid},{rid},{actor},{closed},{created},{identity},{reason},{ids_json}::jsonb) ON CONFLICT(patient_id) DO NOTHING;")
  if ids:statements.append(f"DELETE FROM support_messages WHERE id IN ({','.join(map(str,ids))}) AND thread_id IN (SELECT id FROM support_threads WHERE patient_id={uid});")
  for table,col in [('assistant_reports','patient_id'),('assistant_exchanges','patient_id'),('assistant_preferences','patient_id'),('assistant_usage','patient_id'),('notifications','user_id'),('refresh_sessions','user_id'),('appointment_idempotency','actor_id')]:statements.append(f'DELETE FROM {table} WHERE {col}={uid};')
  statements.append(f"DELETE FROM mail_outbox WHERE recipient=(SELECT email FROM users WHERE id={uid});")
  statements.append(f"UPDATE users SET full_name='Closed account',email='closed-'||md5(random()::text)||'@deleted.invalid',phone='x'||substr(md5(random()::text),1,14),password='!closed!',preferred_treatment=NULL,profile_image_url=NULL,total_points=0,gift_voucher_claimed_at=NULL,otp=NULL,otp_purpose=NULL,otp_expiry=NULL,otp_attempts=0,otp_locked_until=NULL,failed_login_attempts=0,locked_until=NULL,last_login_at=NULL,setup_required=false,is_deleted=true,status='BLOCKED',token_version=token_version+1,profile_version=profile_version+1,updated_at=current_timestamp WHERE id={uid};")
  statements.append(f"UPDATE account_closures SET photo_cleanup_complete=false WHERE patient_id={uid}; INSERT INTO privacy_file_cleanup(patient_id) VALUES ({uid}) ON CONFLICT DO NOTHING; UPDATE privacy_requests SET state='IN_REVIEW' WHERE id={rid};")
 statements.append("SELECT setval(pg_get_serial_sequence('privacy_requests','id'),greatest(coalesce((select max(id) from privacy_requests),1),1)); COMMIT;")
 execute('\n'.join(statements));print('Closure decisions reapplied. Run profile-file cleanup before exposing the restored API.')
