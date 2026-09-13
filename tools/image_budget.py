"""First Workshop image production: durable fail-closed budget and safe metadata."""
import hashlib
import json
import math
import struct
from pathlib import Path

# Revised scope: six projectile/effect sheets, maximum 72 total sends.
# Previous unknown Sora reservation remains retained.
LIMIT_USD = 73.0
LIMIT_REQUESTS = 73
RESERVATION_USD = 1.0

def save(path, data):
    path = Path(path)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    temporary.replace(path)

def validate_history(history, name, fingerprint):
    def acknowledged_unknown(x):
        resolution = x.get('manual_resolution', {})
        return (x['status'] == 'outcome_unknown'
                and resolution.get('action') == 'user_authorized_resume_keep_reservation'
                and (resolution.get('user_message') == '進めてください。' or
                     (x['name'] == 'fw-equipment-rollout-guns-07'
                      and resolution.get('user_message') == '一旦作成のし直しをお願いします。'
                      and resolution.get('retry_name') == 'fw-weapons-diversity-v1'))
                and bool(resolution.get('recorded_at'))
                and bool(resolution.get('retry_name')))
    if any(x['status'] != 'success' and not acknowledged_unknown(x) for x in history):
        raise ValueError('Unresolved attempt: stop and reconcile with user; no retry.')
    if any(x['name'] == name or (x['fingerprint'] == fingerprint and not
           (acknowledged_unknown(x) and x['manual_resolution']['retry_name'] == name)) for x in history):
        raise ValueError('Previously requested asset: additional candidate requires user approval.')
    if len(history) + 1 >= LIMIT_REQUESTS or (len(history) + 1) * RESERVATION_USD >= LIMIT_USD:
        raise ValueError('Conservative budget would reach the authorized limit.')

def usage_record(usage):
    if not isinstance(usage, dict):
        raise ValueError('Usage missing: stop before another generation.')
    details = usage.get('input_tokens_details', {})
    values = [details.get('text_tokens'), details.get('image_tokens'), usage.get('output_tokens')]
    if any(type(v) not in (int, float) or not math.isfinite(v) or v < 0 for v in values):
        raise ValueError('Usage incomplete: stop before another generation.')
    text, image, output = values
    # No caching discount assumed. Pricing-page estimate, not a billing receipt.
    cost = (text * 2.5 + image * 4 + output * 15) / 1_000_000
    safe = dict(input_tokens_details=dict(text_tokens=text, image_tokens=image), output_tokens=output)
    return safe, cost

def reference(path):
    path = Path(path)
    raw = path.read_bytes()
    if not raw.startswith(b'\x89PNG\r\n\x1a\n') or len(raw) > 20 * 1024 * 1024:
        raise ValueError('Reference must be PNG below 20 MiB.')
    width, height = struct.unpack('>II', raw[16:24])
    if max(width, height) > 1536:
        raise ValueError('Reference edge exceeds 1536px production cost envelope.')
    return raw, hashlib.sha256(raw).hexdigest()
