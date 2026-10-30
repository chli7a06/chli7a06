"""Optional isolated MariaDB schema/migration validation. Requires Docker; no host DB or ports."""
from pathlib import Path
import subprocess,time,uuid,re
root=Path(__file__).resolve().parent.parent
name='crimson-mdt-test-'+uuid.uuid4().hex[:10]
image='mariadb@sha256:d1891ede5a559f1086f55053bb8cc1569b0298338c4d72d71725a7f74f6ba620'
count=0
def sql(statement):
 p=subprocess.run(['docker','exec','-i',name,'mariadb','-uroot','crimson_test','--batch','--skip-column-names'],input=statement,text=True,capture_output=True,timeout=20)
 if p.returncode:raise AssertionError(p.stderr)
 return p.stdout.strip()
def check(actual,expected,label):
 global count
 assert actual==expected,(label,actual,expected)
 count+=1
try:
 subprocess.run(['docker','run','--rm','-d','--name',name,'--network','none','--tmpfs','/var/lib/mysql:rw,size=512m','-e','MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=1','-e','MARIADB_DATABASE=crimson_test',image],check=True,capture_output=True,text=True,timeout=20)
 for _ in range(80):
  ready=subprocess.run(['docker','exec',name,'healthcheck.sh','--connect','--innodb_initialized'],capture_output=True,timeout=5)
  if ready.returncode==0:break
  time.sleep(.25)
 else:raise AssertionError('MariaDB failed readiness')
 schema=(root/'crimson_doj/schema.sql').read_text();sql(schema);sql(schema)
 check(sql('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE()'),'16','idempotent schema with all tables')
 sql("""INSERT INTO crimson_mdt_entries(id,scope,kind,subject,title,body,details,owner,updated_by) VALUES
 (1,'justice','case','CIV','Case','Original','{}','STAFF','STAFF'),
 (2,'medical','medical','CIV','Medical','Private','{}','MEDIC','MEDIC'),
 (3,'business:mechanic','invoice','CIV','Invoice','Repair','{\"total\":100,\"payment\":\"unpaid\"}','STAFF','STAFF'),
 (4,'justice','note','','Private note','Hidden','{}','OTHER','OTHER');""")
 check(sql("SELECT COUNT(*) FROM crimson_mdt_entries WHERE scope='justice' AND kind='case'"),'1','legal partition')
 check(sql("SELECT COUNT(*) FROM crimson_mdt_entries WHERE scope='justice' AND kind='medical'"),'0','medical isolation')
 check(sql("SELECT COUNT(*) FROM crimson_mdt_entries WHERE scope='business:burgershot' AND kind='invoice'"),'0','company isolation')
 check(sql("SELECT COUNT(*) FROM crimson_mdt_entries WHERE scope='justice' AND kind='note' AND owner='STAFF'"),'0','private note owner filter')
 check(sql("UPDATE crimson_mdt_entries SET title='Revised',version=version+1 WHERE id=1 AND version=1;SELECT ROW_COUNT();"),'1','first revision applies')
 check(sql("UPDATE crimson_mdt_entries SET title='Lost update',version=version+1 WHERE id=1 AND version=1;SELECT ROW_COUNT();"),'0','stale revision denied')
 sql("""CREATE TABLE crimson_doj_records(id INT PRIMARY KEY,kind VARCHAR(16),citizenid VARCHAR(64),title VARCHAR(160),body MEDIUMTEXT,status VARCHAR(16),created_by VARCHAR(64),updated_by VARCHAR(64),version INT,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
 INSERT INTO crimson_doj_records(id,kind,citizenid,title,body,status,created_by,updated_by,version) VALUES(101,'document','CIV','Legacy','Legacy contents','open','STAFF','STAFF',4);""")
 source=(root/'crimson_doj/server.lua').read_text();migration=re.findall(r'query="(INSERT INTO crimson_mdt_entries\(id,[^\n]+?)",values=\{\}',source);assert len(migration)==1
 marker="INSERT INTO crimson_mdt_migrations(name) VALUES('v1_records')"
 sql('START TRANSACTION;'+migration[0]+';'+marker+';COMMIT;')
 check(sql("SELECT CONCAT(id,':',scope,':',version) FROM crimson_mdt_entries WHERE id=101"),'101:justice:4','actual legacy migration preserves IDs/versions')
 check(sql('SELECT COUNT(*) FROM crimson_doj_records'),'1','migration preserves old source table')
 sql("INSERT INTO crimson_mdt_prints(ticket,record_id,snapshot,issued_by) VALUES('test-ticket',101,'{\"title\":\"Legacy\",\"body\":\"Legacy contents\",\"version\":4}','STAFF');UPDATE crimson_mdt_entries SET body='Changed later' WHERE id=101;")
 check(sql("SELECT JSON_UNQUOTE(JSON_EXTRACT(snapshot,'$.body')) FROM crimson_mdt_prints WHERE ticket='test-ticket'"),'Legacy contents','printed snapshot immutable')
 check(sql("INSERT IGNORE INTO crimson_mdt_payments(entry_id,kind,payer,account,amount,reason,state) VALUES(3,'invoice','CIV','mechanic',100,'Repair','debiting');SELECT ROW_COUNT();"),'1','unique settlement claim')
 check(sql("INSERT IGNORE INTO crimson_mdt_payments(entry_id,kind,payer,account,amount,reason,state) VALUES(3,'invoice','CIV','mechanic',100,'Repair','debiting');SELECT ROW_COUNT();"),'0','duplicate settlement rejected')
 extra=(root/'crimson_doj/server_extras.lua').read_text();statement=re.search(r'query="(UPDATE crimson_mdt_entries SET details=JSON_SET[^\n]+?)",values=',extra).group(1)
 escaped=statement.replace("'","''")
 sql("SET @path='$.payment',@amount=100,@reason='Repair',@actor='CIV',@entry=3;PREPARE paid_update FROM '"+escaped+"';START TRANSACTION;UPDATE crimson_mdt_payments SET state='paid' WHERE entry_id=3;EXECUTE paid_update USING @path,@amount,@reason,@actor,@entry;COMMIT;DEALLOCATE PREPARE paid_update;")
 check(sql("SELECT CONCAT(JSON_UNQUOTE(JSON_EXTRACT(details,'$.payment')),':',JSON_EXTRACT(details,'$.paidAmount')) FROM crimson_mdt_entries WHERE id=3"),'paid:100','actual parameterized JSON payment update')
 sql("START TRANSACTION;UPDATE crimson_mdt_payments SET state='failed' WHERE entry_id=3;ROLLBACK;")
 check(sql('SELECT state FROM crimson_mdt_payments WHERE entry_id=3'),'paid','journal transaction rollback')
 check(sql("INSERT IGNORE INTO crimson_mdt_custody(entry_id,citizenid,minutes,actor,reason,state) VALUES(1,'CIV',10,'STAFF','Test','processing');SELECT ROW_COUNT();"),'1','custody claim schema')
 check(sql("INSERT IGNORE INTO crimson_mdt_custody(entry_id,citizenid,minutes,actor,reason,state) VALUES(1,'CIV',10,'STAFF','Test','processing');SELECT ROW_COUNT();"),'0','custody cannot replay')
 sql("INSERT INTO crimson_mdt_entries(id,scope,kind,subject,title,body,details,owner,updated_by) VALUES(102,'justice','document','','Waiting','Text','{}','STAFF','STAFF'),(103,'medical','document','','Other department','Text','{}','MEDIC','MEDIC');")
 queue=re.search(r'MySQL.query.await\(\[\[(SELECT e.id,e.title[\s\S]+?)\]\],\{a.scope\}\)',source).group(1).replace('?', "'justice'",1)
 check(sql(queue),'102\tWaiting','printer queue excludes historical printed copies and other scopes')
 sql("INSERT INTO crimson_mdt_prints(ticket,record_id,snapshot,issued_by) VALUES('failed-copy',102,'{}','STAFF');DELETE FROM crimson_mdt_prints WHERE ticket='failed-copy';")
 check(sql(queue),'102\tWaiting','failed inventory copy cleanup keeps document queued')
 sql("INSERT INTO crimson_mdt_prints(ticket,record_id,snapshot,issued_by) VALUES('delivered-copy',102,'{}','STAFF');")
 check(sql(queue),'','successful print leaves the printer queue')
 check(sql("SELECT COUNT(*) FROM crimson_mdt_entries WHERE scope='justice' AND kind='document'"),'2','printed documents stay in MDT')
 check(sql("INSERT IGNORE INTO crimson_mdt_entities(scope,kind,entity_id,data,updated_by) VALUES('justice','citizen','CIV','{\"wanted\":true}','STAFF');SELECT ROW_COUNT();"),'1','extended entity creation')
 check(sql("UPDATE crimson_mdt_entities SET data='{\"wanted\":false}',version=version+1 WHERE scope='justice' AND kind='citizen' AND entity_id='CIV' AND version=1;SELECT ROW_COUNT();"),'1','extended optimistic revision')
 check(sql("UPDATE crimson_mdt_entities SET data='{}' WHERE scope='justice' AND kind='citizen' AND entity_id='CIV' AND version=1;SELECT ROW_COUNT();"),'0','stale entity update rejected')
 sql("CREATE TABLE players(citizenid VARCHAR(64) PRIMARY KEY,metadata LONGTEXT);INSERT INTO players VALUES('CIV','{\"licences\":{\"driver\":true},\"other\":7}');UPDATE players SET metadata=JSON_SET(COALESCE(metadata,'{}'),'$.licences.weapon',JSON_EXTRACT('true','$')) WHERE citizenid='CIV';")
 check(sql("SELECT CONCAT(JSON_EXTRACT(metadata,'$.licences.weapon'),':',JSON_EXTRACT(metadata,'$.licences.driver'),':',JSON_EXTRACT(metadata,'$.other')) FROM players"),'true:true:7','offline native license merge preserves metadata')
 check(sql("INSERT IGNORE INTO crimson_mdt_signatures(print_id,signer,signer_name) VALUES(1,'CIV','Citizen');SELECT ROW_COUNT();"),'1','printed signature claim')
 check(sql("INSERT IGNORE INTO crimson_mdt_signatures(print_id,signer,signer_name) VALUES(1,'CIV','Changed');SELECT ROW_COUNT();"),'0','signature cannot be rewritten')
 sql("INSERT INTO crimson_mdt_armory_stock(job,item,amount) VALUES('doj','radio',3);")
 import concurrent.futures
 with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:
  results=list(pool.map(lambda _:sql("UPDATE crimson_mdt_armory_stock SET amount=amount-2 WHERE job='doj' AND item='radio' AND amount>=2;SELECT ROW_COUNT();"),range(2)))
 check(':'.join(sorted(results)),'0:1','concurrent stock claims cannot overspend')
 sql("INSERT INTO crimson_mdt_armory_loans(ticket,item,citizenid,job,remaining,state) VALUES('LOAN','radio','CIV','doj',2,'returning');START TRANSACTION;UPDATE crimson_mdt_armory_stock SET amount=amount+2 WHERE job='doj' AND item='radio';UPDATE crimson_mdt_armory_loans SET state=IF(remaining-2>0,'active','returned'),remaining=remaining-2 WHERE ticket='LOAN' AND item='radio';COMMIT;")
 check(sql("SELECT CONCAT(state,':',remaining) FROM crimson_mdt_armory_loans WHERE ticket='LOAN'"),'returned:0','return accounting and SQL assignment order')
 check(sql("SELECT amount FROM crimson_mdt_armory_stock WHERE job='doj' AND item='radio'"),'3','stock restored after return')
 sql("INSERT INTO crimson_mdt_entities(scope,kind,entity_id,data,updated_by) VALUES('justice','weapon_seen','SER%_!','{}','inventory_sensor'),('justice','weapon_seen','SERABC','{}','inventory_sensor');")
 registry=(root/'crimson_doj/server_registry.lua').read_text()
 serial_query=re.search(r"\[\[(SELECT entity_id,data,updated_at FROM crimson_mdt_entities WHERE scope='justice'[^\n]+?)\]\]",registry).group(1)
 check(sql(serial_query.replace('?',"'%SER!%!_!!%'",1)).split('\t')[0],'SER%_!','actual registry serial search treats wildcard characters literally')
 sql("INSERT INTO crimson_mdt_entities(scope,kind,entity_id,data,updated_by) VALUES('justice','camera','CAM1','{\"x\":449.29,\"bucket\":0}','STAFF');")
 check(sql("SELECT CONCAT(JSON_EXTRACT(data,'$.bucket'),':',version) FROM crimson_mdt_entities WHERE scope='justice' AND kind='camera' AND entity_id='CAM1'"),'0:1','camera uses existing scoped versioned storage')
 print(f'PASS {count} real MariaDB schema, isolation, migration, snapshot and journal checks')
finally:
 subprocess.run(['docker','rm','-f',name],capture_output=True,timeout=15)
