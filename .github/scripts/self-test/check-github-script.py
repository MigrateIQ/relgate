"""Syntax-check the JavaScript embedded in `actions/github-script` steps.
 
yamllint only sees these blocks as opaque text, and a typo in them would
otherwise surface only on a live pull request. Each `script: |` block is
extracted, its ${{ ... }} expressions replaced with a harmless literal (the
real values only exist at run time), wrapped in an async function, and run
through `node --check`.
 
Usage: python check-github-script.py <action-or-workflow.yml> ...
"""
 
import os
import re
import subprocess
import sys
import tempfile
 
EXPRESSION = re.compile(r"\$\{\{.*?\}\}", re.DOTALL)
 
 
def script_blocks(text):
    """Yield (starting line number, dedented script) for each `script: |`."""
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        match = re.match(r"^(\s*)script:\s*\|[-+]?\s*$", lines[i])
        if not match:
            i += 1
            continue
        key_indent = len(match.group(1))
        start = i + 2  # 1-based line number of the first script line
        body = []
        i += 1
        while i < len(lines):
            line = lines[i]
            if line.strip() and len(line) - len(line.lstrip()) <= key_indent:
                break
            body.append(line)
            i += 1
        indents = [len(b) - len(b.lstrip()) for b in body if b.strip()]
        cut = min(indents) if indents else 0
        yield start, "\n".join(b[cut:] for b in body)
 
 
def main(paths):
    failures = 0
    checked = 0
    for path in paths:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        for start, script in script_blocks(text):
            checked += 1
            source = EXPRESSION.sub("0", script)
            wrapped = "(async () => {\n" + source + "\n})();\n"
            with tempfile.NamedTemporaryFile(
                "w", suffix=".js", delete=False, encoding="utf-8"
            ) as tmp:
                tmp.write(wrapped)
                name = tmp.name
            try:
                result = subprocess.run(
                    ["node", "--check", name],
                    capture_output=True,
                    text=True,
                )
            finally:
                os.unlink(name)
            if result.returncode != 0:
                failures += 1
                print(f"::error file={path},line={start}::"
                      f"github-script block has a syntax error")
                print(result.stderr)
    print(f"checked {checked} github-script block(s), {failures} failed")
    return 1 if failures else 0
 
 
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
 