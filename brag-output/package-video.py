"""Create posters, preserve frame counts/audio, and install both web variants."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

out = Path(__file__).resolve().parent
public = out.parent/'apps/web/public/media'
public.mkdir(parents=True, exist_ok=True)
results = {}

def inspect(file):
    probe = json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_entries',
        'stream=codec_name,codec_type,width,height,avg_frame_rate,nb_frames,duration:format=duration,size',
        '-of', 'json', str(file)
    ]))
    audio = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(file), '-map', '0:a', '-c', 'copy', '-f', 'adts', '-'])
    return dict(probe=probe, audioSha256=hashlib.sha256(audio).hexdigest())

for suffix, dimensions in [('', (1920, 1080)), ('-portrait', (1080, 1920))]:
    source = out/f'brag{suffix}.render.mp4'
    target = out/f'brag{suffix}.mp4'
    poster = out/f'brag{suffix}.jpg'
    before = inspect(source)
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-ss', '12.8', '-i', str(source), '-frames:v', '1', '-q:v', '2', str(poster)], check=True)
    subprocess.run([
        'ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(source), '-i', str(poster),
        '-filter_complex', "[0:v][1:v]overlay=0:0:enable='eq(n,0)'[v]", '-map', '[v]', '-map', '0:a?',
        '-c:v', 'libx264', '-crf', '18', '-preset', 'slow', '-pix_fmt', 'yuv420p',
        '-c:a', 'copy', '-movflags', '+faststart', str(target)
    ], check=True)
    after = inspect(target)
    assert before['audioSha256'] == after['audioSha256'], 'Audio must remain unchanged'
    for record in [before, after]:
        video = next(s for s in record['probe']['streams'] if s['codec_type'] == 'video')
        assert (video['width'], video['height']) == dimensions
        assert video['nb_frames'] == '630' and video['avg_frame_rate'] == '30/1'
        assert abs(float(video['duration']) - 21) < 0.001
    results[source.name] = before
    results[target.name] = after
    shutil.copyfile(target, public/f'exerly-phone-logging{suffix}.mp4')
    shutil.copyfile(poster, public/f'exerly-phone-logging{suffix}.jpg')

(out/'media-verification.json').write_text(json.dumps(results, indent=2)+'\n')
print('Both 21-second films and posters installed; dimensions, 630 frames, and unchanged audio verified.')
