"""Read-only upstream monitor. Never executes code fetched from upstream."""
import json
import os
import pathlib
import urllib.request

root = pathlib.Path(__file__).resolve().parent.parent
baseline = json.loads((root / 'upstream.json').read_text())
headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'BiliPai-iOS-upstream-monitor'}
if os.environ.get('GH_TOKEN'):
    headers['Authorization'] = 'Bearer ' + os.environ['GH_TOKEN']
req = urllib.request.Request('https://api.github.com/repos/jay3-yy/BiliPai/releases/latest', headers=headers)
with urllib.request.urlopen(req, timeout=30) as response:
    release = json.load(response)
changed = release['tag_name'] != baseline['release']
report = {'baseline': baseline, 'latest_release': release['tag_name'], 'release_url': release['html_url'], 'changed': changed, 'note': 'New Android features require source porting and review. Rebuild is not automatic feature parity.'}
(root / 'build').mkdir(exist_ok=True)
(root / 'build/upstream-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
if os.environ.get('GITHUB_OUTPUT'):
    with open(os.environ['GITHUB_OUTPUT'], 'a') as out:
        out.write('changed=' + str(changed).lower() + '\n')
if os.environ.get('GITHUB_STEP_SUMMARY'):
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as out:
        out.write('上游发布：' + release['html_url'] + '\n\n' + ('检测到新版本，需要移植审查；将运行当前 iOS 版本回归构建。' if changed else '没有新的上游发布。') + '\n')
print(json.dumps(report, ensure_ascii=False))
