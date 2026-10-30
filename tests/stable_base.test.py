from pathlib import Path
from zipfile import ZipFile
root=Path(__file__).resolve().parents[1]
with ZipFile(root/'downloads/crimson_doj_4.0.0_preview.zip')as base:
 for name in ['web/extensions.js','web/style.css','config.lua','penal_code.lua','schema.sql','client_badge.lua','server_badge.lua','server_banking.lua','bank_adapters.lua','client_blips.lua','server_blips.lua']:
  assert (root/'crimson_doj'/name).read_bytes()==base.read('crimson_doj/'+name),name+' must retain the working 4.0 implementation'
 app=(root/'crimson_doj/web/app.js').read_text().replace("seal.src='doj-logo.png'","seal.src='doj-logo.svg'")
 assert app==base.read('crimson_doj/web/app.js').decode(),'only the badge image path may differ in base app logic'
 client=(root/'crimson_doj/client.lua').read_text().replace("requestWhileOpen(data.custom and 'cameraDefinition' or 'camera', {id=data.id})","requestWhileOpen('camera', {id=data.id})")
 client=client.replace("    if CrimsonBodycamView and CrimsonBodycamView.isActive()then cb({ok=false,error='Stop bodycam recording before viewing security cameras'});return end\n",'')
 assert client==base.read('crimson_doj/client.lua').decode(),'native client differences stay limited to custom camera selection and recording camera conflict check'
 html=(root/'crimson_doj/web/index.html').read_text().replace('<script src="registry.js"></script>','').replace('src="doj-logo.png" alt="Department of Justice seal"','src="crimson-logo.png" alt="Crimson RP"')
 assert html==base.read('crimson_doj/web/index.html').decode(),'HTML only adds the registry script and requested logo source'
 manifest=(root/'crimson_doj/fxmanifest.lua').read_text()
 assert all(word not in manifest for word in ['i18n.js','ui_health.js','operations.js','client_operations.lua']),'no experimental 4.1 opening/localization components'
print('PASS stable 4.0 opening, focus, content, permissions and UI preservation checks')
