import sys
import unittest
import tempfile
import io
import contextlib
from unittest.mock import patch, MagicMock
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from datetime import datetime, timezone
from image_budget import validate_history, usage_record, budget_status, load_config
import generate_image

class BudgetTests(unittest.TestCase):
    def test_fail_closed(self):
        for status in ['pending', 'received', 'budget_review_required']:
            with self.assertRaises(ValueError):
                validate_history([dict(status=status, name='a', fingerprint='b')], 'c', 'd')
    def test_monthly_budget_before_send(self):
        config = dict(monthly_budget_usd=1.0, request_reserve_usd=.25)
        now = datetime(2026, 10, 5, tzinfo=timezone.utc)
        spent = [dict(status='success', name=str(i), fingerprint=str(i), sent_at='2026-10-01T00:00:00+00:00',
                      pricing_estimate_usd=.25) for i in range(3)]
        validate_history(spent, 'new', 'new', config, now)  # 0.75 used + 0.25 reserve fits exactly
        with self.assertRaises(ValueError):
            validate_history(spent + [dict(spent[0], name='x', fingerprint='x', pricing_estimate_usd=.01)], 'new', 'new', config, now)
        # Other months do not count; unknown-cost sends count at the reserve.
        old = [dict(status='success', name='o', fingerprint='o', sent_at='2026-09-30T23:00:00+00:00', pricing_estimate_usd=50)]
        self.assertEqual(budget_status(old, config, now)['spent'], 0)
        unknown = dict(status='outcome_unknown', name='u', fingerprint='u', sent_at='2026-10-02T00:00:00+00:00', reserved_usd=1.0)
        self.assertAlmostEqual(budget_status([unknown], config, now)['spent'], .25)
        status = budget_status(spent[:1], config, now, planned=3)
        self.assertTrue(status['fits'] and status['affordable'] == 3)
        self.assertFalse(budget_status(spent[:1], config, now, planned=4)['fits'])

    def test_config_and_override(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'budget.json'
            path.write_text('{"monthly_budget_usd": 20, "request_reserve_usd": 0.25}', encoding='utf-8')
            self.assertEqual(load_config(path, {})['monthly_budget_usd'], 20)
            self.assertEqual(load_config(path, {'IMAGE_MONTHLY_BUDGET_USD': '5'})['monthly_budget_usd'], 5)
            with self.assertRaises(ValueError): load_config(path, {'IMAGE_MONTHLY_BUDGET_USD': 'nan'})

    def test_explicit_resume_keeps_unknown_and_limits_retry(self):
        record = dict(status='outcome_unknown', name='old', fingerprint='same')
        with self.assertRaises(ValueError): validate_history([record], 'retry', 'same')
        record['manual_resolution'] = dict(action='user_authorized_resume_keep_reservation',
            user_message='進めてください。', recorded_at='2026-09-12', retry_name='retry')
        validate_history([record], 'retry', 'same')
        self.assertEqual(record['status'], 'outcome_unknown')
        with self.assertRaises(ValueError): validate_history([record], 'other', 'same')
        with self.assertRaises(ValueError): validate_history([record], 'old', 'different')
        success = dict(status='success', name='retry', fingerprint='same')
        with self.assertRaises(ValueError): validate_history([record, success], 'retry2', 'same')
    def test_duplicate(self):
        with self.assertRaises(ValueError):
            validate_history([dict(status='success', name='old', fingerprint='same')], 'new', 'same')

    def test_interrupted_equipment_redesign_is_explicit_and_keeps_reservation(self):
        record = dict(status='outcome_unknown',name='fw-equipment-rollout-guns-07',fingerprint='old-design',
            reserved_usd=1.0,manual_resolution=dict(action='user_authorized_resume_keep_reservation',
            user_message='一旦作成のし直しをお願いします。',recorded_at='2026-09-12',retry_name='fw-weapons-diversity-v1'))
        validate_history([record],'fw-weapons-diversity-v1','new-design')
        self.assertEqual(record['reserved_usd'],1.0)
        with self.assertRaises(ValueError): validate_history([record],'unapproved-retry','old-design')
        record['name']='another-unknown'
        with self.assertRaises(ValueError): validate_history([record],'fw-weapons-diversity-v1','new-design')
    def test_usage(self):
        _, cost = usage_record(dict(input_tokens_details=dict(text_tokens=1000,image_tokens=1000),output_tokens=1000))
        self.assertAlmostEqual(cost, .0215)
        for bad in [None, {}, dict(input_tokens_details=dict(text_tokens=0,image_tokens=0),output_tokens=float('nan'))]:
            with self.assertRaises(ValueError): usage_record(bad)

    def test_failed_post_is_reserved_and_not_retried(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder)
            opener = MagicMock()
            opener.open.side_effect = TimeoutError('private-server-details')
            log = io.StringIO()
            with patch.object(generate_image,'OUTPUT',output), patch.object(generate_image,'load_key',return_value='private-key'), patch.object(generate_image,'https_opener',return_value=opener), patch.object(sys,'argv',['generate_image.py','--name','test']), contextlib.redirect_stderr(log), contextlib.redirect_stdout(log):
                self.assertEqual(generate_image.main(),2)
                with self.assertRaises(ValueError): generate_image.main()
            self.assertEqual(opener.open.call_count,1)
            self.assertNotIn('private',log.getvalue())
            self.assertNotIn('private', (output/'first-workshop-usage.json').read_text())
            self.assertTrue((output/'first-workshop.lock').exists())

if __name__ == '__main__': unittest.main()
