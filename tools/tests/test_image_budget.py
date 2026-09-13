import sys
import unittest
import tempfile
import io
import contextlib
from unittest.mock import patch, MagicMock
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from image_budget import validate_history, usage_record
import generate_image

class BudgetTests(unittest.TestCase):
    def test_fail_closed(self):
        for status in ['pending', 'received', 'budget_review_required']:
            with self.assertRaises(ValueError):
                validate_history([dict(status=status, name='a', fingerprint='b')], 'c', 'd')
    def test_limit_before_send(self):
        history = [dict(status='success',name=str(i),fingerprint=str(i)) for i in range(72)]
        with self.assertRaises(ValueError): validate_history(history, 'new', 'new')
        validate_history(history[:71], 'new', 'new')

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
