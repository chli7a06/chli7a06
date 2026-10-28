const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process'),parser=require('luaparse');
const root=path.resolve(__dirname,'..');
for(const file of ['config.lua','defaults.lua','fxmanifest.lua','client.lua','server.lua','server_extras.lua','server_badge.lua','server_banking.lua','bank_adapters.lua','INSTALL/ox_inventory-items.lua','INSTALL/prison-items.lua'])parser.parse(fs.readFileSync(path.join(root,'crimson_doj',file),'utf8'),{luaVersion:'5.3'});
let run=spawnSync(process.execPath,['--check','crimson_doj/web/app.js'],{cwd:root,encoding:'utf8'});assert.equal(run.status,0,run.stderr);
console.log('PASS Lua and JavaScript syntax');
run=spawnSync(process.execPath,[require.resolve('fengari-node-cli/src/lua-cli.js'),'tests/server.test.lua'],{cwd:root,encoding:'utf8',timeout:15000});
assert.equal(run.status,0,run.stderr);assert.match(run.stdout,/PASS 82 authorization/);assert.doesNotMatch(run.stderr,/stack traceback|assertion failed/);console.log(run.stdout.trim().split('\n').at(-1));
run=spawnSync(process.execPath,['tests/ui.test.cjs'],{cwd:root,encoding:'utf8',timeout:20000});assert.equal(run.status,0,run.stderr);assert.match(run.stdout,/PASS 65 UI checks/);console.log(run.stdout.trim());

run=spawnSync(process.execPath,[require.resolve('fengari-node-cli/src/lua-cli.js'),'tests/client.test.lua'],{cwd:root,encoding:'utf8',timeout:15000});assert.equal(run.status,0,run.stderr);assert.match(run.stdout,/PASS 37 client/);assert.doesNotMatch(run.stderr,/stack traceback|assertion failed/);console.log(run.stdout.trim());

run=spawnSync(process.execPath,[require.resolve('fengari-node-cli/src/lua-cli.js'),'tests/services.test.lua'],{cwd:root,encoding:'utf8',timeout:15000});assert.equal(run.status,0,run.stderr);assert.match(run.stdout,/PASS 55 service checks/);assert.doesNotMatch(run.stderr,/stack traceback|assertion failed/);console.log(run.stdout.trim());

for(const file of ['crimson_doj/media_core.cjs','crimson_doj/server_media.js']){run=spawnSync(process.execPath,['--check',file],{cwd:root,encoding:'utf8'});assert.equal(run.status,0,run.stderr);}
run=spawnSync(process.execPath,['tests/media.test.cjs'],{cwd:root,encoding:'utf8',timeout:15000});assert.equal(run.status,0,run.stderr);assert.match(run.stdout,/PASS 14 media/);console.log(run.stdout.trim());

run=spawnSync(process.execPath,['tests/media-wrapper.test.cjs'],{cwd:root,encoding:'utf8',timeout:15000});assert.equal(run.status,0,run.stderr);assert.match(run.stdout,/PASS 14 actual Node/);console.log(run.stdout.trim().split('\n').at(-1));

run=spawnSync(process.execPath,[require.resolve('fengari-node-cli/src/lua-cli.js'),'tests/badge.test.lua'],{cwd:root,encoding:'utf8',timeout:15000});assert.equal(run.status,0,run.stderr);assert.match(run.stdout,/PASS badge authorization/);assert.doesNotMatch(run.stderr,/stack traceback|assertion failed/);console.log(run.stdout.trim());
run=spawnSync(process.execPath,['--check','crimson_doj/web/badge.js'],{cwd:root,encoding:'utf8'});assert.equal(run.status,0,run.stderr);

run=spawnSync(process.execPath,[require.resolve('fengari-node-cli/src/lua-cli.js'),'tests/banking.test.lua'],{cwd:root,encoding:'utf8',timeout:15000});assert.equal(run.status,0,run.stderr);assert.match(run.stdout,/PASS .* banking adapter checks/);assert.doesNotMatch(run.stderr,/stack traceback|assertion failed/);console.log(run.stdout.trim());

run=spawnSync(process.execPath,[require.resolve('fengari-node-cli/src/lua-cli.js'),'tests/printer-target.test.lua'],{cwd:root,encoding:'utf8',timeout:15000});assert.equal(run.status,0,run.stderr);assert.match(run.stdout,/PASS printer target zones/);assert.doesNotMatch(run.stderr,/stack traceback|assertion failed/);console.log(run.stdout.trim());
