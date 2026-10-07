"""Build the film from the most recent successful simulator capture."""
import json
from pathlib import Path
import shutil
import subprocess

out = Path(__file__).resolve().parent
project = out / 'composition'
capture = json.loads((out / 'phone-capture.json').read_text())
assert capture['testExit'] == 0 and 'end' in capture['phases']
source = out / capture['video']
if not source.exists():
    source = project/'assets/ui/phone-source.mp4'
probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'json', str(source)]))
# Simulator recordings can omit the final idle seconds. Their duration therefore
# cannot calibrate the start timestamp. Use the wall-clock markers from the
# recorder launch, then visually verify each cut against the native screen.
duration = float(probe['format']['duration'])
phase = {key: max(0, value) for key, value in capture['phases'].items()}
if source.resolve() != (project/'assets/ui/phone-source.mp4').resolve():
    shutil.copyfile(source, project / 'assets/ui/phone-source.mp4')
for name in ['diary', 'summary']:
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-ss', str(min(duration-0.1, phase[name]+0.6)),
                    '-i',str(source),'-frames:v','1',str(project / f'assets/ui/phone-{name}.png')], check=True)
ranges = {
    'pick': dict(start=3.27, duration=5.47, source=phase['recents']+0.2, rate=1.35),
    'portion': dict(start=8.74, duration=4.37, source=phase['serving']+0.4, rate=1.9),
    'save': dict(start=13.11, duration=4.36, source=phase['save'], rate=2),
}
(out/'edit-ranges.json').write_text(json.dumps(dict(sourceDuration=duration, phases=phase, clips=ranges), indent=2))
energy = json.loads((project/'assets/music/energy.json').read_text())
(project/'assets/music/energy.js').write_text('const AUDIO_DATA = '+json.dumps(energy, separators=(',',':'))+';')
videos = '\n'.join(f'<video id="phone-{name}" class="clip screen" src="assets/ui/phone-source.mp4" data-start="{r["start"]}" data-duration="{r["duration"]}" data-media-start="{r["source"]:.3f}" data-playback-rate="{r["rate"]}" data-track-index="2" muted playsinline></video>' for name,r in ranges.items())
html = '''<!doctype html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=1920,height=1080">
<title>Exerly on iPhone</title><script src="assets/gsap.min.js"></script><script src="assets/music/energy.js"></script>
<style>
@font-face{font-family:Inter;src:url('assets/fonts/InterVariable.woff2') format('woff2');font-weight:100 900;font-display:block}
*{box-sizing:border-box}html,body{margin:0;width:1920px;height:1080px;background:#0a0a0f;color:#e9ebf1;font-family:Inter,sans-serif}
#root{position:relative;width:100%;height:100%;overflow:hidden;background:#0a0a0f}
#light{position:absolute;left:820px;top:0;width:1050px;height:1080px;background:radial-gradient(ellipse,#8b5cf6 0%,transparent 68%);opacity:.12}
.brand{position:absolute;left:126px;top:90px;font-size:48px;font-weight:750;letter-spacing:-2px}
.brand i{display:inline-block;width:13px;height:34px;border-radius:8px;background:#a78bfa;margin-right:16px}
.rule{position:absolute;left:130px;top:218px;width:710px;height:2px;background:#343140;transform-origin:left}
.copy{position:absolute;left:126px;top:300px;width:870px;height:600px}
.copy h1,.copy h2{margin:0;font-size:112px;line-height:1.08;letter-spacing:-6px;font-weight:750}
.copy h1 span,.copy h2 span{display:block;width:100%}.accent{color:#a78bfa}
.eyebrow{margin:0 0 28px;font-size:26px;color:#bdc1ce;font-weight:500}
.detail{font-size:31px;line-height:1.5;color:#b2b9c9;max-width:670px;margin:38px 0 0}
.footer{position:absolute;left:130px;bottom:75px;font-size:25px;color:#a7afbf}
#phone{position:absolute;left:1200px;top:48px;width:454px;height:980px;border:7px solid #42414c;border-radius:65px;background:#0c0c11;box-shadow:0 28px 80px #0009;overflow:hidden}
.screen{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
.cta{display:inline-flex;align-items:center;margin-top:38px;padding:23px 34px;border:2px solid #a78bfa;border-radius:18px;color:#e9ebf1;font-size:29px;font-weight:650;gap:32px}
#outro h2{font-size:80px;letter-spacing:-3.5px;line-height:1.14}
</style></head><body>
<div id="root" data-composition-id="exerly-phone" data-start="0" data-duration="21" data-width="1920" data-height="1080">
<div id="light" data-layout-ignore></div><div class="brand"><i></i>Exerly</div><div class="rule" data-layout-ignore></div>
<section id="hook" class="clip copy" data-start="0" data-duration="3.27" data-track-index="0"><p class="eyebrow">A little less effort. A little more clarity.</p><h1 class="hf-catalog-line-by-line-slide"><span>Your day.</span><span class="accent">In one place.</span></h1></section>
<section id="pick" class="clip copy" data-start="3.27" data-duration="5.47" data-track-index="0"><p class="eyebrow">01 / Choose</p><h2><span>Pick</span><span class="accent">your meal.</span></h2><p class="detail">Your recent foods, ready when you are.</p></section>
<section id="portion" class="clip copy" data-start="8.74" data-duration="4.37" data-track-index="0"><p class="eyebrow">02 / Adjust</p><h2><span>Make it</span><span class="accent">your portion.</span></h2><p class="detail">Set the amount. The numbers follow.</p></section>
<section id="save" class="clip copy" data-start="13.11" data-duration="4.36" data-track-index="0"><p class="eyebrow">03 / Save</p><h2><span>Logged.</span><span class="accent">Already counted.</span></h2></section>
<section id="outro" class="clip copy" data-start="17.47" data-duration="3.53" data-track-index="0"><p class="eyebrow">Nutrition, movement, sleep, and progress.</p><h2><span>Fitness,</span><span class="accent">precisely tracked.</span></h2><div class="cta">Open Exerly <span aria-hidden="true">↗</span></div></section>
<div id="phone"><img id="phone-diary" class="clip screen" src="assets/ui/phone-diary.png" data-start="0" data-duration="3.27" data-track-index="2" alt="Exerly iPhone diary">
__VIDEOS__
<img id="phone-summary" class="clip screen" src="assets/ui/phone-summary.png" data-start="17.47" data-duration="3.53" data-track-index="2" alt="Diary after the meal is saved"></div>
<div class="footer">iPhone app preview · Demo account</div>
<audio id="music" src="assets/music/bed.wav" data-start="0" data-duration="21" data-track-index="10" data-volume="0.55"></audio>
<audio id="reveal" src="assets/sfx/reveal.wav" data-start="3.27" data-duration="0.18" data-track-index="11" data-volume="0.55"></audio>
<audio id="click" src="assets/sfx/click.wav" data-start="13.8" data-duration="0.02" data-track-index="12" data-volume="0.55"></audio>
</div><script>
const tl=gsap.timeline({paused:true});
// Catalog line-by-line-slide recipe, with the product's own type and no blur.
// beat-grid: 0.56s and 1.09s, followed by a readable hold.
tl.fromTo('#hook h1 span',{opacity:0,x:-36,y:18},{opacity:1,x:0,y:0,duration:.34,stagger:.53,ease:'power3.out'},.56);
tl.fromTo('#phone',{x:100,scale:.94,opacity:0},{x:0,scale:1,opacity:1,duration:.7,ease:'power3.out'},0);
tl.fromTo('.rule',{scaleX:0},{scaleX:1,duration:.7,ease:'power2.out'},.1);
for(const [id,time] of [['pick',3.27],['portion',8.74],['save',13.11],['outro',17.47]]){
  // beat-locked: portion 8.74s; outro 17.47s.
  tl.fromTo('#'+id+' h2 span',{opacity:0,x:-28},{opacity:1,x:0,duration:.36,stagger:.09,ease:'power3.out'},time);
  tl.fromTo('#'+id+' .eyebrow',{opacity:0,y:10},{opacity:1,y:0,duration:.25,ease:'power2.out'},time);
}
tl.fromTo('#outro .cta',{opacity:0,y:16},{opacity:1,y:0,duration:.4,ease:'power2.out'},17.9);
// Precomputed audio samples, applied on the same deterministic timeline.
for(let f=0;f<AUDIO_DATA.frames.length;f++){
  const frame=AUDIO_DATA.frames[f];
  tl.set('#light',{opacity:.10+.05*frame.rms},f/AUDIO_DATA.fps);
}
window.__timelines=window.__timelines || {};
window.__timelines['exerly-phone']=tl;
</script></body></html>'''
(project/'index.html').write_text(html.replace('__VIDEOS__', videos))
(project/'index.motion.json').write_text(json.dumps({'duration':21,'assertions':[
    {'kind':'appearsBy','selector':'#phone','bySec':0.8},
    {'kind':'staysInFrame','selector':'#phone'},
    {'kind':'appearsBy','selector':'#outro .cta','bySec':18.5}
]},indent=2))
portrait_css = '''
html,body{width:1080px;height:1920px}
.brand{left:72px;top:44px}
.rule,.eyebrow,.detail{display:none}
.copy{left:72px;top:148px;width:936px;height:220px}
.copy h1,.copy h2,#outro h2{font-size:80px;letter-spacing:-4px;line-height:1.08}
#phone{left:215px;top:355px;width:650px;height:1406px}
#light{left:0;width:1080px;height:1920px}
.footer{left:72px;bottom:90px;font-size:24px}
#outro .cta{position:absolute;top:-104px;right:0;margin:0;padding:13px 20px;font-size:24px;gap:22px}
'''
portrait = html.replace('__VIDEOS__', videos).replace('width=1920,height=1080', 'width=1080,height=1920')
portrait = portrait.replace('margin:0;width:1920px;height:1080px;', 'margin:0;width:1080px;height:1920px;')
portrait = portrait.replace('data-width="1920" data-height="1080"', 'data-width="1080" data-height="1920"')
portrait = portrait.replace('exerly-phone', 'exerly-phone-portrait').replace('</style>', portrait_css+'</style>')
portrait_project = out/'portrait'
portrait_project.mkdir(exist_ok=True)
if not (portrait_project/'assets').exists():
    (portrait_project/'assets').symlink_to('../composition/assets', target_is_directory=True)
(portrait_project/'index.html').write_text(portrait)
shutil.copyfile(project/'index.motion.json', portrait_project/'index.motion.json')
shutil.copyfile(project/'package.json', portrait_project/'package.json')
shutil.copyfile(project/'hyperframes.json', portrait_project/'hyperframes.json')
print(json.dumps(ranges, indent=2))
