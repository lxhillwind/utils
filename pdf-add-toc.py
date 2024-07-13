#!/usr/bin/env python3

import re
import argparse

import pypdf

toc_format = r'''
    toc format:

    example to specify page number offset: `# offset: 1 -> 12` (take effect for following toc);
    lines starting with `#` and empty lines are ignored;
    indent level as toc level;
    number (with leading space) at end of line is page number;
    '''

parser = argparse.ArgumentParser(usage=toc_format)
parser.add_argument('-i', required=True, help='pdf file (input)')
parser.add_argument('-o', required=True, help='pdf file (output)')
parser.add_argument('-c', required=True, help='toc')
args = parser.parse_args()

def parse_offset(line: str) -> int:
    # example: `# offset: 1 -> 12`
    t1, t2 = re.findall(r'\d+', line)
    return int(t2) - int(t1)

def parse_toc(line: str) -> dict:
    leading_whitespace = 0
    if re.search('^ +', line):
        leading_whitespace = re.match('^ +', line).group(0).count(' ')
    if g['indent'] < 0 and leading_whitespace > 0:
        g['indent'] = leading_whitespace

    level = 0
    if leading_whitespace:
        level = int(leading_whitespace / g['indent'])

    i = re.search(r' \d+$', line)
    title = line[leading_whitespace:i.start()]
    page_number = int(line[i.start():]) + g['offset']
    return {'title': title, 'page_number': page_number, 'level': level}

toc = []
g = {
    'indent': -1, # modify it on first indent
    'offset': 0,
    }
with open(args.c) as f:
    for line in f.readlines():
        line = line.rstrip()
        if re.match(r'^#\s*offset:', line):
            g['offset'] = parse_offset(line)
        elif re.match(r'^(#|\s*$)', line):
            continue
        else:
            toc.append(parse_toc(line))

reader = pypdf.PdfReader(args.i)
writer = pypdf.PdfWriter(clone_from=reader)

toc_level_stack = {0: None}
for i in toc:
    toc_level_stack[i['level'] + 1] = writer.add_outline_item(
            title=i['title'],
            page_number=i['page_number'] - 1, # zero-based
            parent=toc_level_stack[i['level']],
        )

with open(args.o, 'wb') as f:
    writer.write(f)
