"""Generate original seamless synthetic pressure-spray and foam loops (no sampled recordings)."""
from pathlib import Path
import subprocess
import tempfile
import wave
import numpy as np

OUT = Path(__file__).resolve().parents[1] / 'crimson-mechanic/web/audio'
OUT.mkdir(parents=True, exist_ok=True)
RATE, DURATION = 44100, 4
COUNT = RATE * DURATION
time = np.arange(COUNT) / RATE
rng = np.random.default_rng(18410)
frequency = np.fft.rfftfreq(COUNT, 1 / RATE)

def noise(low, high):
    spectrum = rng.normal(size=len(frequency)) + 1j * rng.normal(size=len(frequency))
    shape = (1 - np.exp(-(frequency / low) ** 2)) * np.exp(-(frequency / high) ** 4)
    signal = np.fft.irfft(spectrum * shape, n=COUNT)
    return signal / np.sqrt(np.mean(signal * signal))

water = (.8 * noise(900, 10000) + .22 * noise(130, 1800))
water *= .94 + .04 * np.sin(2 * np.pi * 3 * time) + .02 * np.sin(2 * np.pi * 23 * time)
water += .035 * np.sin(2 * np.pi * 180 * time)
foam = (.55 * noise(350, 6200) + .3 * noise(80, 1200))
foam *= .85 + .1 * np.sin(2 * np.pi * 1.5 * time) + .05 * np.sin(2 * np.pi * 4.25 * time)
for _ in range(38):
    start = rng.uniform(0, DURATION)
    duration = rng.uniform(.025, .065)
    t = (time - start) % DURATION
    envelope = np.where(t < duration, np.sin(np.pi * np.minimum(t / duration, 1)) ** 2, 0)
    foam += .09 * envelope * np.sin(2 * np.pi * (rng.uniform(500, 1700) * t - 1800 * t * t))

for name, signal in [('water', water), ('foam', foam)]:
    signal = signal * (.20 / np.sqrt(np.mean(signal * signal)))
    signal = .9 * np.tanh(signal / .9)
    pcm = np.round(signal * 32767).astype('<i2')
    with tempfile.TemporaryDirectory() as temp:
        source = Path(temp) / 'loop.wav'
        with wave.open(str(source), 'wb') as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(RATE)
            audio.writeframes(pcm.tobytes())
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(source), '-c:a', 'libvorbis', '-q:a', '4',
                        str(OUT / f'wash_{name}.ogg')], check=True)
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(source), '-ar', '22050', '-c:a', 'pcm_s16le',
                        str(OUT / f'wash_{name}.wav')], check=True)
print('Created seamless synthetic water/foam spray loops')
