from pathlib import Path
p = Path('game/scripts/Main.gd')
t = p.read_text()
old = 'worker_text = "%s\nTechnical %d  •  %d/%d" % [current["name"], int(current["skills"]["Technical"]), current_index + 1, avail.size()]'
# In the current commit the quoted source contains a literal newline. Replace
# that with the two-character GDScript escape sequence so the label still wraps.
needle = 'worker_text = "%s' + chr(10) + 'Technical %d  •  %d/%d" % [current["name"], int(current["skills"]["Technical"]), current_index + 1, avail.size()]'
if needle not in t:
    raise SystemExit('worker label literal-newline anchor not found')
t = t.replace(needle, 'worker_text = "%s\\nTechnical %d  •  %d/%d" % [current["name"], int(current["skills"]["Technical"]), current_index + 1, avail.size()]', 1)
p.write_text(t)
Path('.github/scripts/temp_worker_label_fix.py').unlink(missing_ok=True)
print('FIRST_FIRE_WORKER_LABEL_FIX_OK')
