#!/usr/bin/env python3
#
# Chromium line based log merging for running Lacros with Ash
# ¯                    ¯                      ¯           ¯
# Usage:
#  export LACROS_LOG_PATH=<expected_lacros_log_path>
#  cola.py <ash_chrome_args_that_runs_lacros...>

import sys
import os
import subprocess
import signal
import fileinput
import threading
import atexit
import argparse
import re
import time
from datetime import datetime

# TODO: Figure out integration with Ash+Lacros browsertest

# Default path assumes Ash user-data-dir is ../profiles/ash (qjw's chromium_rc setup)
lacros_log_file = os.environ.get('LACROS_LOG_PATH', '../profiles/ash/lacros/lacros.log')

# Pluck args we know (the names are deliberately short, and are unlikely to clash with chromium args).
parser = argparse.ArgumentParser(description = "Helper script to run Ash and Lacros, merge and colorize their logs")
parser.add_argument("-i", "--only-important", action='store_true', help="Only show important messages")
args, ash_cmd = parser.parse_known_args()

# Clear existing file logs for `tail -f`
if os.path.isfile(lacros_log_file):
    with open(lacros_log_file, "w") as file:
        pass

proc_tail = subprocess.Popen(
    ["/usr/bin/tail", "-F", lacros_log_file],
    stdin=None,
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
    encoding="utf-8",
)

print(ash_cmd)

proc_main = subprocess.Popen(
    ash_cmd,
    shell=False,
    stdin=None,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    encoding="utf-8"
)

# Signal handlers
def exit_handler(arg0=None, arg1=None):
    proc_main.send_signal(signal.SIGTERM)
    proc_tail.send_signal(signal.SIGTERM)
signal.signal(signal.SIGINT, exit_handler)
signal.signal(signal.SIGTERM, exit_handler)
atexit.register(exit_handler)

# Achtung! Dodgy way to get Ash process exit event (e.g. a crash), then exit self.
def ash_exit_watcher():
    proc_main.wait()
    exit_handler()
threading.Thread(daemon=True, target=ash_exit_watcher, args=()).start()

stdout_lock = threading.Lock()

# Achtung! Dodgy way to handle File IO like events.
def line_handler(f, lock, line_mapper=lambda x: x):
    try:
        for line in f:
            # TODO: Filter out less useful lines?
            # TODO: Drop non syslog format lines?
            line = line_mapper(line)
            if not line:
                continue
            with lock:
                sys.stdout.write(line)
                sys.stdout.flush()
    except Exception as e:
        print(e, file=sys.stderr)

class tesc:
    # B for background
    B_BLUE = '\033[48;5;17m'
    B_GREEN = '\033[48;5;22m'

    # F for foreground
    F_WHITE = '\033[38;5;255m'
    F_L_BLUE = '\033[38;5;195m'
    F_L_GREEN = '\033[38;5;194m'
    F_BLUE = '\033[38;5;153m'
    F_GREEN = '\033[38;5;158m'
    F_D_BLUE = '\033[38;5;75m'
    F_D_GREEN = '\033[38;5;82m'

    # Bold styling
    F_BOLD = '\033[1m'

    # Reset to default color
    END = '\033[0m'

# Line handlers and utilities
def concise_syslog_line(line, fg_gradient=[]):
    # syslog format patterns
    re_iso_8601 = r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,}Z'
    re_level = r'[A-Z]{3,}'
    re_process_thread = r'(?:[a-zA-Z_0-9\-]+)\[(?:\d+):(?:\d+)\]'
    re_file_linenumber = r'\[[a-zA-Z_0-9.\-]+\(\d+\)\]'
    re_syslog_line = fr'({re_iso_8601})\s*({re_level})\s*({re_process_thread}):\s*({re_file_linenumber})\s*(.+)'

    def get_importance(line):
        # RegExp that when matched, mark the line as important and gives it eye-catching styling
        # TODO: make this configurable
        re_importance_hints = r'(\*{3,})|system_(web_)?app|web_ui|webui'
        if len(re.findall(re_importance_hints, line)) > 0:
            return 1
        return 0

    # Determine importance and skip message if necessary
    importance = get_importance(line)
    if args.only_important and importance < 1:
        return None

    def syslog_line_rewrite(m):
        # Pick styling based on importance
        base_gradient = min(importance, len(fg_gradient)-1)
        fg1_esc = fg_gradient[base_gradient]
        fg2_esc = fg_gradient[base_gradient+1]
        if base_gradient > 0:
            fg1_esc = tesc.F_BOLD + fg1_esc
            fg2_esc = tesc.F_BOLD + fg2_esc

        # Time rewrite
        # Replace the trailing 'Z' with TZ offset, because python3<3.11 can't parse it.
        # WTF py?
        iso_str = m[1].replace('Z', '+00:00')
        dt = datetime.fromisoformat(iso_str).astimezone()
        frac_str = '%03d' % int(round(dt.microsecond / 1000))
        time_str = f'T{dt.strftime(r"%H:%M:%S")}.{frac_str}' # TODO:color this

        # Rewrite the following if needed.
        level_str = m[2].ljust(7)  # Longest level string is WARNING (7 chars)
        process_thread_str = m[3]
        file_linenumber_str = m[4]
        message_str = m[5]

        return f'{fg1_esc}{time_str} {level_str} {process_thread_str} {file_linenumber_str}: {tesc.END}{fg2_esc}{message_str}{tesc.END}'

    return re.sub(re_syslog_line, syslog_line_rewrite, line)

def ash_line_handler(line):
    prefix = f'{tesc.B_BLUE}{tesc.F_WHITE} Ash    {tesc.END} {tesc.F_L_BLUE}'
    suffix = f'{tesc.END}'

    line = concise_syslog_line(line, [tesc.F_L_BLUE, tesc.F_BLUE, tesc.F_D_BLUE])

    return f'{prefix}{line}{suffix}' if line else None

def lacros_line_handler(line):
    prefix = f'{tesc.B_GREEN}{tesc.F_WHITE} Lacros {tesc.END} {tesc.F_L_GREEN}'
    suffix = f'{tesc.END}'

    line = concise_syslog_line(line, [tesc.F_L_GREEN, tesc.F_GREEN, tesc.F_D_GREEN])

    return f'{prefix}{line}{suffix}' if line else None

# Spawn log merges.
t1 = threading.Thread(
    target=line_handler,
    args=(proc_main.stdout, stdout_lock, ash_line_handler))
t1.start()

t2 = threading.Thread(
    target=line_handler,
    args=(proc_tail.stdout, stdout_lock, lacros_line_handler))
t2.start()

t1.join()
t2.join()

