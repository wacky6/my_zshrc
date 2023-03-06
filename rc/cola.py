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

# TODO: Figure out integration with Ash+Lacros browsertest

# Default path assumes Ash user-data-dir is ../profiles/ash (qjw's chromium_rc setup)
lacros_log_file = os.environ.get('LACROS_LOG_PATH', '../profiles/ash/lacros/lacros.log')

# Pluck args we know (the names are deliberately short, and are unlikely to clash with chromium args).
parser = argparse.ArgumentParser(description = "Helper script to run Ash and Lacros, merge and colorize their logs")
parser.add_argument("-g", "--grep", action='store_true', help="<TODO> Only show lines of interest")
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

proc_main = subprocess.Popen(
    ash_cmd,
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
def line_wrap(f, lock, prefix='', suffix=''):
    try:
        for line in f:
            # TODO: Filter out less useful lines
            # TODO: Chop out time line?
            with lock:
                sys.stdout.write(prefix+line+suffix)
                sys.stdout.flush()
    except Exception as e:
        print(e, file=sys.stderr)

class term_colors:
    # B for background
    B_BLUE = '\033[48;5;17m'
    B_GREEN = '\033[48;5;22m'
    
    # F for foreground
    F_WHITE = '\033[38;5;255m'
    F_PINK = '\033[38;5;225m'
    F_BLUE = '\033[38;5;117m'
    F_GREEN = '\033[38;5;194m'

    # Reset to default color
    END = '\033[0m'

# Spawn log merges.
ash_prefix = f'{term_colors.B_BLUE}{term_colors.F_WHITE} Ash    {term_colors.END} {term_colors.F_BLUE}'
lacros_prefix = f'{term_colors.B_GREEN}{term_colors.F_WHITE} Lacros {term_colors.END} {term_colors.F_GREEN}'
suffix = f'{term_colors.END}'

t1 = threading.Thread(
    target=line_wrap,
    args=(proc_main.stdout, stdout_lock, ash_prefix, suffix))
t1.start()

t2 = threading.Thread(
    target=line_wrap,
    args=(proc_tail.stdout, stdout_lock, lacros_prefix, suffix))
t2.start()

t1.join()
t2.join()

