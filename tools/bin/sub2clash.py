#!/usr/bin/env python3
"""Convert a proxy subscription into a mihomo (Clash Meta) config.yaml.

Usage:
    python3 sub2clash.py INPUT [ -o OUTPUT ] [ -c ]

INPUT can be a subscription URL (http/https, downloaded with a Clash UA) or a
local file. The content may be base64-encoded or plaintext node lines
(hysteria2://, vless://, vmess://, ss://, trojan://).
Supports: hysteria2, vless (reality / ws+tls). Other protocols are skipped.
"""
import argparse
import base64
import sys
import urllib.request
from urllib.parse import parse_qs, unquote

# ANSI colors for clear feedback
C_GREEN = '\033[0;32m'
C_YELLOW = '\033[0;33m'
C_RED = '\033[0;31m'
C_NC = '\033[0m'


def fetch_subscription(url, timeout=60, ua='clash-verge/v2.0.2'):
    """Download a subscription URL and return its text content."""
    req = urllib.request.Request(url, headers={'User-Agent': ua})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode('utf-8', 'replace')


def load_input_text(input_arg):
    """Return the raw text of a subscription URL or a local file."""
    if input_arg.startswith(('http://', 'https://')):
        return fetch_subscription(input_arg).strip()
    with open(input_arg, 'r', encoding='utf-8', errors='replace') as f:
        return f.read().strip()


def parse_nodes(raw):
    """Extract node lines from base64 or plaintext content."""
    # Auto-decode if the content is base64 (no scheme-looking lines)
    if '://' not in raw:
        try:
            decoded = base64.b64decode(raw).decode('utf-8', 'replace')
            if '://' in decoded:
                raw = decoded
        except Exception:
            pass
    nodes = []
    for line in raw.splitlines():
        line = line.strip()
        if line.startswith(('hysteria2://', 'vless://', 'vmess://', 'ss://', 'trojan://')):
            nodes.append(line)
    return nodes


def frag_name(uri):
    if '#' in uri:
        return unquote(uri.split('#', 1)[1]) or 'node'
    return 'node'


def parse_hysteria2(uri):
    rest = uri[len('hysteria2://'):].split('#', 1)[0]
    name = frag_name(uri)
    query = {}
    if '?' in rest:
        rest, qs = rest.split('?', 1)
        query = parse_qs(qs)
    if '@' in rest:
        password, hostport = rest.split('@', 1)
    else:
        password, hostport = '', rest
    host, port = hostport.rsplit(':', 1)
    node = {
        'name': name,
        'type': 'hysteria2',
        'server': host,
        'port': int(port.rstrip('/')),
        'password': password,
        'skip-cert-verify': True,
    }
    if query.get('sni'):
        node['sni'] = query['sni'][0]
    return node


def parse_vless(uri):
    rest = uri[len('vless://'):].split('#', 1)[0]
    name = frag_name(uri)
    if '@' in rest:
        uuid, hostport = rest.split('@', 1)
    else:
        uuid, hostport = '', rest
    query = {}
    if '?' in hostport:
        hostport, qs = hostport.split('?', 1)
        query = parse_qs(qs)
    host, port = hostport.rsplit(':', 1)
    node = {
        'name': name,
        'type': 'vless',
        'server': host,
        'port': int(port.rstrip('/')),
        'uuid': uuid,
        'udp': True,
    }
    net = query.get('type', ['tcp'])[0]
    sec = query.get('security', ['none'])[0]
    node['network'] = net
    if sec in ('tls', 'reality'):
        node['tls'] = True
        if query.get('sni'):
            node['servername'] = query['sni'][0]
        if query.get('fp'):
            node['client-fingerprint'] = query['fp'][0]
    if sec == 'reality':
        node['flow'] = query.get('flow', ['xtls-rprx-vision'])[0]
        node['reality-opts'] = {}
        if query.get('pbk'):
            node['reality-opts']['public-key'] = query['pbk'][0]
        if query.get('sid'):
            node['reality-opts']['short-id'] = query['sid'][0]
    if net == 'ws':
        node['ws-opts'] = {}
        if query.get('path'):
            node['ws-opts']['path'] = query['path'][0]
        if query.get('host'):
            node['ws-opts']['headers'] = {'Host': query['host'][0]}
    return node


def yaml_scalar(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, int):
        return str(v)
    return '"%s"' % v


def proxies_block(proxies):
    lines = []
    for p in proxies:
        lines.append('  - name: "%s"' % p['name'])
        for k, v in p.items():
            if k == 'name':
                continue
            if isinstance(v, dict):
                lines.append('    %s:' % k)
                for kk, vv in v.items():
                    if isinstance(vv, dict):
                        lines.append('      %s:' % kk)
                        for kkk, vvv in vv.items():
                            lines.append('        %s: %s' % (kkk, yaml_scalar(vvv)))
                    else:
                        lines.append('      %s: %s' % (kk, yaml_scalar(vv)))
            else:
                lines.append('    %s: %s' % (k, yaml_scalar(v)))
    return lines


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('input', help='subscription URL or local file (base64 or plaintext)')
    ap.add_argument('-o', '--output', default='mihomo-config.yaml')
    ap.add_argument('-c', '--copy', action='store_true',
                    help='copy the generated config to /etc/mihomo/config.yaml (needs root)')
    args = ap.parse_args()

    raw = load_input_text(args.input)

    # Direct Clash YAML subscription (airport returns a full config) -> use as-is
    if 'proxies:' in raw:
        out_lines = raw.splitlines()
        if not any(l.lstrip().startswith('mixed-port') for l in out_lines):
            out_lines.insert(0, 'mixed-port: 7890')
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write('\n'.join(out_lines) + '\n')
        print('%sGenerated %s (direct Clash YAML subscription).%s'
              % (C_GREEN, args.output, C_NC))
        print('%sTo deploy it:  sudo cp %s /etc/mihomo/config.yaml%s'
              % (C_YELLOW, args.output, C_NC))
        return

    nodes = parse_nodes(raw)
    if not nodes:
        print('%sNo nodes parsed from input.%s' % (C_RED, C_NC), file=sys.stderr)
        sys.exit(1)

    proxies = []
    skipped = 0
    for uri in nodes:
        if uri.startswith('hysteria2://'):
            proxies.append(parse_hysteria2(uri))
        elif uri.startswith('vless://'):
            proxies.append(parse_vless(uri))
        else:
            skipped += 1

    if not proxies:
        print('No supported nodes found (hysteria2/vless)', file=sys.stderr)
        sys.exit(1)

    names = [p['name'] for p in proxies]
    lines = []
    lines.append('mixed-port: 7890')
    lines.append('allow-lan: false')
    lines.append('mode: rule')
    lines.append('log-level: info')
    lines.append('')
    lines.append('proxies:')
    lines.extend(proxies_block(proxies))
    lines.append('')
    lines.append('proxy-groups:')
    lines.append('  - name: "PROXY"')
    lines.append('    type: url-test')
    lines.append('    url: http://www.gstatic.com/generate_204')
    lines.append('    interval: 3600')
    lines.append('    proxies:')
    for n in names:
        lines.append('      - "%s"' % n)
    lines.append('')
    lines.append('rules:')
    lines.append('  - MATCH,PROXY')

    with open(args.output, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')

    print('%sGenerated %s with %d proxies (skipped %d unsupported).%s'
          % (C_GREEN, args.output, len(proxies), skipped, C_NC))
    print('%sTo deploy it:  sudo cp %s /etc/mihomo/config.yaml%s'
          % (C_YELLOW, args.output, C_NC))
    if args.copy:
        try:
            import shutil
            shutil.copy(args.output, '/etc/mihomo/config.yaml')
            print('%sCopied to /etc/mihomo/config.yaml%s' % (C_GREEN, C_NC))
        except Exception as e:
            print('%sAuto-copy failed (%s) - run: sudo cp %s /etc/mihomo/config.yaml%s'
                  % (C_RED, e, args.output, C_NC))


if __name__ == '__main__':
    main()
