"""Check CodeWalker binary->XML output against authored channels and model bounds.

CompileAsset writes .roundtrip.xml files next to the compiled .ycd and .ydr.
These checks include the compiled data, rather than only validating authoring XML.
"""
from pathlib import Path
import json, math, xml.etree.ElementTree as ET

OUT = Path(__file__).resolve().parent

def animation_data(path):
    root = ET.parse(path).getroot()
    clips = {c.findtext('Hash'): c.findtext('AnimationHash') for c in root.find('Clips')}
    animations = {}
    for animation in root.find('Animations'):
        ids = [(int(b.find('BoneId').get('value')), int(b.find('Track').get('value')))
               for b in animation.find('BoneIds')]
        data = animation.find('Sequences/Item/SequenceData')
        channels = {}
        for key, item in zip(ids, data, strict=True):
            channel = item.find('Channels/Item')
            kind = channel.find('Type').get('value')
            value = channel.find('Value')
            channels[key] = (kind, tuple(float(value.get(k)) for k in ('xyzw' if key[1] == 1 else 'xyz')))
        animations[animation.findtext('Hash')] = channels
    return clips, animations

source = OUT / 'crimson_wash_custom_v4.ycd.xml'
binary = OUT / 'crimson_wash_custom_v4.ycd'
expected_clips, expected = animation_data(source)
clips, actual = animation_data(Path(str(binary) + '.roundtrip.xml'))
assert clips == expected_clips and set(clips) == {'carry', 'spray'}
assert actual.keys() == expected.keys()
max_error = 0.
for name, channels in expected.items():
    assert actual[name].keys() == channels.keys()
    assert len(channels) == 46
    for key, (kind, values) in channels.items():
        other_kind, other_values = actual[name][key]
        assert kind == other_kind
        error = max(abs(a - b) for a, b in zip(values, other_values, strict=True))
        assert error < 1e-6, (name, key, error)
        max_error = max(max_error, error)
assert binary.read_bytes()[:4] == b'RSC7'

model = ET.parse(OUT / 'crimson_pressure_washer.ydr.roundtrip.xml').getroot()
original = ET.parse(OUT.parent / 'crimson_lavage_assets/crimson_pressure_washer.ydr.xml').getroot()
delta = float(original.find('BoundingBoxMax').get('x')) - float(model.find('BoundingBoxMax').get('x'))
assert abs(delta - .15) < 1e-6
for tag, axes in [('BoundingBoxMin', 'xyz'), ('BoundingBoxMax', 'yz')]:
    for axis in axes:
        assert abs(float(original.find(tag).get(axis)) - float(model.find(tag).get(axis))) < 1e-6
textures = model.find('ShaderGroup/TextureDictionary')
assert {t.findtext('Name') for t in textures} == {
    t.findtext('Name') for t in original.find('ShaderGroup/TextureDictionary')}
assert (OUT / 'crimson_pressure_washer.ydr').read_bytes()[:4] == b'RSC7'
report = {
    'compiled_ycd_roundtrip': True,
    'clips': sorted(clips),
    'tracks_per_clip': 46,
    'max_channel_error': max_error,
    'compiled_model_shortening_m': delta,
    'embedded_textures': len(textures),
    'live_fivem_tested': False,
}
(OUT / 'compiled_validation.json').write_text(json.dumps(report, indent=2) + '\n')
print('PASS: compiled carry/spray channels preserved, prop shortened 15cm, textures retained')
