from pathlib import Path
from zipfile import ZipFile
root=Path(__file__).resolve().parents[1]
with ZipFile(root/'downloads/crimson_doj_4.0.0_preview.zip')as base:
 for name in ['web/app.js','web/extensions.js','web/style.css','config.lua','permissions.lua','penal_code.lua','schema.sql','client_badge.lua','server_badge.lua','server_banking.lua','bank_adapters.lua','client_blips.lua','server_blips.lua']:
  assert (root/'crimson_doj'/name).read_bytes()==base.read('crimson_doj/'+name),name+' must retain the working 4.0 implementation'
 client=(root/'crimson_doj/client.lua').read_text().replace("requestWhileOpen(data.custom and 'cameraDefinition' or 'camera', {id=data.id})","requestWhileOpen('camera', {id=data.id})")
 assert client==base.read('crimson_doj/client.lua').decode(),'the only native client difference is the custom camera selector'
 html=(root/'crimson_doj/web/index.html').read_text().replace('<script src="registry.js"></script>','')
 assert html==base.read('crimson_doj/web/index.html').decode(),'the only HTML difference is the isolated registry script'
 manifest=(root/'crimson_doj/fxmanifest.lua').read_text()
 assert all(word not in manifest for word in ['i18n.js','ui_health.js','operations.js','client_operations.lua']),'no experimental 4.1 opening/localization components'
print('PASS stable 4.0 opening, focus, content, permissions and UI preservation checks')
