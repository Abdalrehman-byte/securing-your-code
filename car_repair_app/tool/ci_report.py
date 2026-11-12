#!/usr/bin/env python3
"""Builds the CI test report and publishes it.

Usage: ci_report.py <title> <name>=<outcome>=<log file> [...]

The report is written to the GitHub job summary and, when GH_TOKEN is set,
attached to the commit as a check run so it can be read from the Checks tab
or through the GitHub API.
"""
import json
import os
import re
import subprocess
import sys

LIMIT = 64000
ANSI = re.compile(r'\x1b\[[0-9;]*[A-Za-z]')


def clean(text):
    text = ANSI.sub('', text.replace('\r\n', '\n'))
    # Progress lines rewritten with carriage returns: keep the last state.
    return '\n'.join(line.split('\r')[-1] for line in text.split('\n'))


def main():
    title = sys.argv[1]
    sections = []
    for arg in sys.argv[2:]:
        name, outcome, path = arg.split('=', 2)
        try:
            with open(path, encoding='utf-8', errors='replace') as handle:
                log = clean(handle.read())
        except OSError:
            log = '(no log was produced)'
        sections.append((name, outcome, log))

    failed = [name for name, outcome, _ in sections if outcome != 'success']
    budget = (LIMIT - 2000) // max(1, len(sections))
    lines = ['Commit: ' + os.environ.get('GITHUB_SHA', 'local'), '']
    for name, outcome, _ in sections:
        lines.append('- %s: %s' % (name, outcome.upper()))
    for name, outcome, log in sections:
        if len(log) > budget:
            log = '[... earlier output cut ...]\n' + log[-budget:]
        lines += ['', '## %s: %s' % (name, outcome.upper()), '', '```', log.strip(), '```']
    report = '\n'.join(lines)

    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as handle:
            handle.write('# %s\n\n%s\n' % (title, report))

    if os.environ.get('GH_TOKEN') and os.environ.get('GITHUB_REPOSITORY'):
        body = {
            'name': title,
            'head_sha': os.environ['GITHUB_SHA'],
            'status': 'completed',
            'conclusion': 'failure' if failed else 'success',
            'output': {
                'title': 'FAILED: ' + ', '.join(failed) if failed else 'All passed',
                'summary': '\n'.join(lines[: 2 + len(sections)]),
                'text': report[:LIMIT],
            },
        }
        with open('check-run.json', 'w', encoding='utf-8') as handle:
            json.dump(body, handle)
        subprocess.run(
            ['gh', 'api', 'repos/%s/check-runs' % os.environ['GITHUB_REPOSITORY'],
             '--input', 'check-run.json', '--jq', '.html_url'],
            check=False,
        )
        os.remove('check-run.json')
    else:
        print(report)


if __name__ == '__main__':
    main()
