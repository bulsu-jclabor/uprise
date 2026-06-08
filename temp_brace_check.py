from pathlib import Path
import re
text = Path('lib/screens/web/org/org_event_analytics.dart').read_text(encoding='utf-8')
text = re.sub(r'//.*', '', text)
text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
text = re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
text = re.sub(r"'(?:\\.|[^'\\])*'", "''", text)
lines = text.splitlines()
bal = 0
minbal = float('inf')
minline = 0
for i, line in enumerate(lines, 1):
    bal += line.count('{') - line.count('}')
    if bal < minbal:
        minbal = bal
        minline = i
print('final', bal, 'minbal', minbal, 'minline', minline)
