from pathlib import Path

patch = Path('.github/scripts/temp_tactical03d_patch.py')
text = patch.read_text()
old = "pattern = rf'func {re.escape(name)}\\b.*?(?=\\nfunc {re.escape(next_name)}\\b)'"
new = "pattern = rf'(?:static )?func {re.escape(name)}\\b.*?(?=\\n(?:static )?func {re.escape(next_name)}\\b)'"
if old not in text:
    raise SystemExit('replace_func helper anchor missing')
text = text.replace(old, new, 1)
patch.write_text(text)
exec(compile(text, str(patch), 'exec'), {'__name__': '__main__'})
