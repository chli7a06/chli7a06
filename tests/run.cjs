const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process'),parser=require('luaparse');
const root=path.resolve(__dirname,'..');
for(const file of ['config.lua','fxmanifest.lua','client.lua','server.lua'])parser.parse(fs.readFileSync(path.join(root,'crimson_doj',file),'utf8'),{luaVersion:'5.3'});
let run=spawnSync(process.execPath,['--check','crimson_doj/web/app.js'],{cwd:root,encoding:'utf8'});assert.equal(run.status,0,run.stderr);
console.log('PASS Lua and JavaScript syntax');
run=spawnSync(process.execPath,[require.resolve('fengari-node-cli/src/lua-cli.js'),'tests/server.test.lua'],{cwd:root,encoding:'utf8',timeout:15000});
assert.equal(run.status,0,run.stderr);assert.match(run.stdout,/PASS 62 authorization/);assert.doesNotMatch(run.stderr,/stack traceback|assertion failed/);console.log(run.stdout.trim().split('\n').at(-1));
run=spawnSync(process.execPath,['tests/ui.test.cjs'],{cwd:root,encoding:'utf8',timeout:20000});assert.equal(run.status,0,run.stderr);assert.match(run.stdout,/PASS 49 UI checks/);console.log(run.stdout.trim());

run=spawnSync(process.execPath,[require.resolve('fengari-node-cli/src/lua-cli.js'),'tests/client.test.lua'],{cwd:root,encoding:'utf8',timeout:15000});assert.equal(run.status,0,run.stderr);assert.match(run.stdout,/PASS 20 client/);assert.doesNotMatch(run.stderr,/stack traceback|assertion failed/);console.log(run.stdout.trim());
