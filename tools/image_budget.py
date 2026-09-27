"""First Workshop image production: durable fail-closed budget and safe metadata."""
import hashlib
import json
import math
import os
import struct
from datetime import datetime, timezone
from pathlib import Path

# Monthly USD budget (2026-09-27): replaces the old request-count cap that reserved $1 per send and
# had to be raised by hand every task. Spending is summed from the usage-based estimates in the ledger;
# sends without a known cost (pending, failed, outcome unknown) count at the per-request reserve.
# Settings live in image_budget.json; IMAGE_MONTHLY_BUDGET_USD in the environment overrides the amount.
CONFIG = Path(__file__).resolve().with_name('image_budget.json')

def load_config(path=CONFIG, environ=None):
    environ = os.environ if environ is None else environ
    config = json.loads(Path(path).read_text(encoding='utf-8'))
    budget = float(environ.get('IMAGE_MONTHLY_BUDGET_USD', config['monthly_budget_usd']))
    reserve = float(config['request_reserve_usd'])
    if not (math.isfinite(budget) and budget >= 0 and math.isfinite(reserve) and reserve > 0):
        raise ValueError('Invalid image budget configuration.')
    return dict(monthly_budget_usd=budget, request_reserve_usd=reserve)

def month_of(record):
    return str(record.get('sent_at', ''))[:7]

def record_cost(record, reserve):
    cost = record.get('pricing_estimate_usd')
    if type(cost) in (int, float) and math.isfinite(cost) and cost >= 0:
        return float(cost)
    return reserve

def budget_status(history, config, now=None, planned=1):
    now = now or datetime.now(timezone.utc)
    month = now.strftime('%Y-%m')
    reserve = config['request_reserve_usd']
    records = [x for x in history if month_of(x) == month]
    spent = sum(record_cost(x, reserve) for x in records)
    remaining = config['monthly_budget_usd'] - spent
    return dict(month=month, budget=config['monthly_budget_usd'], spent=spent, sends=len(records),
                remaining=remaining, reserve=reserve, planned=planned,
                planned_reserve=planned * reserve, fits=planned * reserve <= remaining + 1e-9,
                affordable=max(0, int((remaining + 1e-9) // reserve)))

def describe(status):
    verdict = 'OK' if status['fits'] else 'OVER BUDGET: do not send'
    return (f"{status['month']}: budget ${status['budget']:.2f}, used ${status['spent']:.2f} in {status['sends']} sends, "
            f"remaining ${status['remaining']:.2f} (about {status['affordable']} more at ${status['reserve']:.2f} each). "
            f"Planned {status['planned']} = up to ${status['planned_reserve']:.2f}: {verdict}.")

def save(path, data):
    path = Path(path)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    temporary.replace(path)

def validate_history(history, name, fingerprint, config=None, now=None):
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
    if not budget_status(history, config or load_config(), now)['fits']:
        raise ValueError('Monthly image budget would be exceeded.')

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
