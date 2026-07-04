#!/usr/bin/env python3

import sys
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

g = {
    'indent': -1, # modify it on first indent
    'offset': 0,
    }

parser = argparse.ArgumentParser(usage=toc_format)
parser.add_argument('-i', required=True, help='pdf file (input)')
parser.add_argument('-o', help='pdf file (output)')
parser.add_argument('-c', help='toc file')
parser.add_argument('--dump-toc', action='store_true', help='output existing toc to stdout')
parser.add_argument('--dump-toc-offset', default=1, type=int, help='specify physical page number of logical page 1 (default: 1)')
args = parser.parse_args()

if not ((args.o and args.c) or args.dump_toc):
    parser.print_help()
    print('\n'
          'expecting one of:'
          '\n\t' '-o and -c'
          '\n\t' '--dump-toc (and optional --dump-toc-offset)',
          file=sys.stderr)
    sys.exit(1)


def parse_offset(line: str) -> int:
    # example: `# offset: 1 -> 12`
    t1, t2 = re.findall(r'-?\d+', line)
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

    i = re.search(r' -?\d+$', line)
    title = line[leading_whitespace:i.start()]
    page_number = int(line[i.start():]) + g['offset']
    return {'title': title, 'page_number': page_number, 'level': level}


def read_toc(args):
    reader = pypdf.PdfReader(args.i)
    toc = reader.outline
    if not toc:
        print('\n' 'WARNING: toc not found in this file.', file=sys.stderr)
        sys.exit(0)

    def parse_outline(toc, indent):
        if isinstance(toc, list):
            for i in toc:
                parse_outline(i, indent + 1)
        else:
            print('%s%s %s' % (
                ' ' * 4 * indent,
                toc.title,
                # get_page_number is 0-based, so +1;
                reader.get_page_number(toc.page) + 1 - (args.dump_toc_offset - 1)
                ))

    if args.dump_toc_offset != 1:
        print(f'# offset: 1 -> {args.dump_toc_offset}')
    parse_outline(toc, -1)


def write_toc(args):
    toc = []
    with open(args.c) as f:
        for line in f.readlines():
            line = line.rstrip()
            if re.match(r'^#\s*offset:', line):
                g['offset'] = parse_offset(line)
            elif re.match(r'^(#|\s*$)', line):
                continue
            else:
                toc.append(parse_toc(line))


    writer = pypdf.PdfWriter()
    writer.append(fileobj=args.i, import_outline=False)

    toc_level_stack = {0: None}
    for i in toc:
        toc_level_stack[i['level'] + 1] = writer.add_outline_item(
                title=i['title'],
                page_number=i['page_number'] - 1, # zero-based
                parent=toc_level_stack[i['level']],
            )

    with open(args.o, 'wb') as f:
        writer.write(f)


if args.dump_toc:
    read_toc(args)
else:
    write_toc(args)
