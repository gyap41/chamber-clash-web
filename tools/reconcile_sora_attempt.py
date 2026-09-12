"""Record this user's explicit resume instruction, without clearing unknown billing."""
from pathlib import Path
from datetime import datetime, timezone
import json
from image_budget import save

root = Path(__file__).resolve().parents[1]
ledger = root / 'assets/generated/first-workshop-usage.json'
lock = root / 'assets/generated/first-workshop.lock'
history = json.loads(ledger.read_text(encoding='utf-8'))
attempt = history[-1]
assert attempt['name'] == 'fw-character-v2-01-sora'
assert attempt['status'] == 'outcome_unknown'
assert lock.read_text() == attempt['name']
assert not (root / 'assets/generated/fw-character-v2-01-sora.png').exists()
attempt['manual_resolution'] = dict(
    action='user_authorized_resume_keep_reservation', user_message='進めてください。',
    recorded_at=datetime.now(timezone.utc).isoformat(),
    retry_name='fw-character-v2-01-sora-retry1', billing_outcome='unknown')
save(ledger, history)
# Preserve the old lock as an audit artifact; a new request receives a new lock.
lock.rename(lock.with_name('fw-character-v2-01-sora.acknowledged-lock'))
print('Unknown attempt and reservation retained; one named retry authorized.')
