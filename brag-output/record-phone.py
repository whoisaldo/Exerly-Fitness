"""Capture real iPhone logging footage against the isolated API on port 39003."""
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time

root = Path(__file__).resolve().parent.parent
out = root / 'brag-output'
device = '28A97E73-F20D-463A-BAAC-2550726030A5'
env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer',
           EXERLY_FIXTURE_EXTERNAL='1', EXERLY_DERIVED_DATA='/tmp/exerly-brag-derived',
           EXERLY_TEST_DESTINATION=f'platform=iOS Simulator,id={device}',
           TEST_RUNNER_EXERLY_BRAG_CAPTURE='1')
run = time.strftime('%Y%m%d-%H%M%S')
log_path = out / f'phone-{run}.log'
video_path = out / f'phone-{run}.mp4'
bundle = out / f'phone-{run}.xcresult'
subprocess.run(['xcrun', 'simctl', 'status_bar', device, 'override', '--time', '9:41', '--batteryState', 'charged', '--batteryLevel', '100'], env=env, check=True)
recorder = None
started = None
try:
    with log_path.open('w') as log, (out / f'phone-{run}-recording.log').open('w') as record_log:
        test = subprocess.Popen(['bash', 'scripts/ios.sh', 'test',
            '-only-testing:ExerlyUITests/ProductionUITests/testLandingPagePhoneLoggingCapture',
            '-resultBundlePath', str(bundle)], cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT)
        while test.poll() is None:
            content = log_path.read_text()
            if 'EXERLY_BRAG ready ' in content and recorder is None:
                started = time.time()
                recorder = subprocess.Popen(['xcrun', 'simctl', 'io', device, 'recordVideo', '--codec=h264', str(video_path)],
                    env=env, stdout=record_log, stderr=subprocess.STDOUT)
            if 'EXERLY_BRAG end ' in content and recorder is not None and recorder.poll() is None:
                recorder.send_signal(signal.SIGINT)
                recorder.wait(timeout=15)
            time.sleep(0.25)
        if recorder is not None and recorder.poll() is None:
            recorder.send_signal(signal.SIGINT)
            recorder.wait(timeout=15)
        phases = {name: float(stamp) - started for name, stamp in re.findall(r'EXERLY_BRAG (\w+) ([\d.]+)', log_path.read_text())} if started else {}
        manifest = dict(video=video_path.name, result=bundle.name, log=log_path.name, phases=phases, testExit=test.returncode)
        (out / f'phone-{run}.json').write_text(json.dumps(manifest, indent=2))
        print(json.dumps(manifest, indent=2), flush=True)
        if test.returncode or 'end' not in phases:
            raise SystemExit('Phone recording did not complete successfully. Inspect the retained log.')
        (out / 'phone-capture.json').write_text(json.dumps(manifest, indent=2))
finally:
    if recorder is not None and recorder.poll() is None:
        recorder.send_signal(signal.SIGINT)
        recorder.wait(timeout=15)
    subprocess.run(['xcrun', 'simctl', 'status_bar', device, 'clear'], env=env, check=False)
