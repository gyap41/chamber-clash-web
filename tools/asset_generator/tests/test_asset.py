import contextlib
import io
import json
import os
import ssl
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import urllib.error
import wave

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import asset
import config
import transport
from providers import stable_audio, elevenlabs


def wav_bytes():
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(44100)
        stream.writeframes(b"\0\0" * 4410)
    return buffer.getvalue()


class AssetTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.audio = self.root / "assets/audio"
        self.audio.mkdir(parents=True)
        (self.audio / "asset_manifest.json").write_text('{"schema_version":1,"assets":[]}', encoding="utf-8")
        (self.root / "docs").mkdir()
        (self.root / "docs/AUDIO_BIBLE.md").write_text("test", encoding="utf-8")
        self.keys = {"STABILITY_API_KEY": "test-secret-stability", "ELEVENLABS_API_KEY": "test-secret-eleven"}
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        for name, value in {"ROOT": self.root, "AUDIO": self.audio, "STATE": self.root / ".local"}.items():
            self.stack.enter_context(patch.object(asset, name, value))
        self.stack.enter_context(patch.object(asset, "load_keys", return_value=self.keys))
        self.stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
        self.send = self.stack.enter_context(patch.object(asset, "generate", return_value=wav_bytes()))

    def args(self, *extra):
        return ["bgm", "--name", "test_battle", "--prompt", "Sparse electronic battle music", *extra]

    def test_dry_run_never_calls_or_writes(self):
        before = sorted(str(p) for p in self.root.rglob("*"))
        asset.run(self.args("--dry-run"))
        self.send.assert_not_called()
        self.assertEqual(before, sorted(str(p) for p in self.root.rglob("*")))

    def test_success_manifest_and_duplicate_prevention(self):
        asset.run(self.args())
        manifest = json.loads((self.audio / "asset_manifest.json").read_text())
        entry = manifest["assets"][0]
        self.assertAlmostEqual(entry["duration"], 0.1)
        self.assertEqual(entry["file_path"], "res://assets/audio/bgm/test_battle.wav")
        self.assertFalse(entry["loop_verified"])
        with self.assertRaises(ValueError):
            asset.run(self.args())
        with self.assertRaises(ValueError):
            asset.run(self.args("--name", "another_name"))
        self.assertEqual(self.send.call_count, 1)
        asset.run(self.args("--name", "explicit_variant", "--allow-repeat"))
        self.assertEqual(self.send.call_count, 2)
        for path in self.root.rglob("*.json"):
            text = path.read_text()
            for secret in self.keys.values():
                self.assertNotIn(secret, text)

    def test_timeout_reserves_conditions_and_does_not_retry(self):
        self.send.side_effect = transport.GenerationError("Timeout")
        with self.assertRaises(transport.GenerationError):
            asset.run(self.args())
        with self.assertRaises(ValueError):
            asset.run(self.args("--name", "another_name"))
        self.assertEqual(self.send.call_count, 1)
        attempts = json.loads((self.root / ".local/attempts.json").read_text())
        self.assertEqual(attempts[0]["status"], "failed_or_uncertain")

    def test_lock_blocks_concurrent_calls(self):
        state = self.root / ".local"
        state.mkdir()
        (state / "generator.lock").write_text("123")
        with self.assertRaises(ValueError):
            asset.run(self.args())
        self.send.assert_not_called()

    def test_invalid_parameters_are_rejected_before_network(self):
        for extra in [("--name", "../escape"), ("--name", "con"), ("--duration", "nan"),
                      ("--timeout", "inf"), ("--duration", "191"), ("--seed", "-1")]:
            with self.subTest(extra=extra), self.assertRaises(ValueError):
                asset.run(self.args(*extra))
        self.send.assert_not_called()

    def test_secret_arguments_rejected_even_dry_run(self):
        with self.assertRaises(ValueError):
            asset.run(self.args("--purpose", self.keys["STABILITY_API_KEY"], "--dry-run"))
        self.send.assert_not_called()

    def test_bad_audio_kept_for_recovery(self):
        self.send.return_value = b"not audio"
        with self.assertRaises(ValueError):
            asset.run(self.args())
        self.assertTrue((self.root / ".local/bgm_test_battle.wav").exists())
        self.assertEqual(json.loads((self.audio / "asset_manifest.json").read_text())["assets"], [])

    def test_missing_key_and_corrupt_manifest_do_not_call(self):
        self.keys["STABILITY_API_KEY"] = ""
        with self.assertRaises(ValueError):
            asset.run(self.args())
        self.keys["STABILITY_API_KEY"] = "test-secret-stability"
        (self.audio / "asset_manifest.json").write_text("not json")
        with self.assertRaises(ValueError):
            asset.run(self.args())
        self.send.assert_not_called()

    def test_manifest_save_failure_preserves_audio_without_retry(self):
        original = asset.atomic_json
        def fail_manifest(path, value):
            if path.name == "asset_manifest.json":
                raise OSError("disk full")
            original(path, value)
        with patch.object(asset, "atomic_json", side_effect=fail_manifest), self.assertRaises(OSError):
            asset.run(self.args())
        self.assertTrue((self.root / ".local/bgm_test_battle.wav").exists())
        self.assertTrue((self.audio / "bgm/test_battle.wav").exists())
        with self.assertRaises(ValueError):
            asset.run(self.args())
        self.assertEqual(self.send.call_count, 1)


class ProtocolTests(unittest.TestCase):
    def test_opener_identifies_application_and_keeps_redirect_guard(self):
        with patch.object(transport, "tls_context") as context, \
                patch.object(transport.urllib.request, "build_opener") as factory:
            opener = transport.https_opener()
            self.assertEqual(opener.addheaders, [("User-Agent", transport.USER_AGENT)])
            handlers = factory.call_args.args
            self.assertIsInstance(handlers[0], transport.NoRedirect)
            self.assertIsInstance(handlers[1], transport.urllib.request.HTTPSHandler)
            context.assert_called_once_with()

    def test_windows_root_selection_and_explicit_ca(self):
        with patch.object(transport.sys, "platform", "win32"), \
                patch.object(transport.ssl, "SSLContext") as factory, \
                patch.object(transport.ssl, "enum_certificates", create=True) as enum, \
                patch.object(transport.ssl, "DER_cert_to_PEM_cert", side_effect=lambda c: c.decode()), \
                patch.dict(os.environ, {"SSL_CERT_FILE": "custom.pem", "SSL_CERT_DIR": "custom-ca"}, clear=True):
            enum.return_value = [(b"root1", "x509_asn", True),
                                 (b"root2", "x509_asn", {ssl.Purpose.SERVER_AUTH.oid}),
                                 (b"wrong-purpose", "x509_asn", {"other"}),
                                 (b"wrong-format", "pkcs_7_asn", True)]
            transport.tls_context()
            enum.assert_called_once_with("ROOT")
            factory.assert_called_once_with(ssl.PROTOCOL_TLS_CLIENT)
            calls = factory.return_value.load_verify_locations.call_args_list
            self.assertEqual(calls[0].kwargs, {"cadata": "root1root2"})
            self.assertEqual(calls[1].kwargs, {"cafile": "custom.pem", "capath": "custom-ca"})

    def test_empty_windows_roots_fail_closed(self):
        with patch.object(transport.sys, "platform", "win32"), \
                patch.object(transport.ssl, "enum_certificates", return_value=[], create=True), \
                self.assertRaises(transport.GenerationError):
            transport.tls_context()

    def test_non_windows_uses_platform_defaults(self):
        with patch.object(transport.sys, "platform", "linux"), \
                patch.object(transport.ssl, "create_default_context") as default:
            self.assertIs(transport.tls_context(), default.return_value)
            default.assert_called_once_with()

    def test_tls_verification_remains_required(self):
        with patch.dict(os.environ, {}, clear=True):
            context = transport.tls_context()
        self.assertEqual(context.verify_mode, ssl.CERT_REQUIRED)
        self.assertTrue(context.check_hostname)

    def test_certificate_error_is_safe_and_not_retried(self):
        with patch.object(transport, "https_opener") as factory:
            factory.return_value.open.side_effect = urllib.error.URLError(
                ssl.SSLCertVerificationError(1, "SECRET certificate details"))
            with self.assertRaises(transport.GenerationError) as caught:
                transport.generate("https://example.test", {}, b"{}", 5)
            self.assertIn("TLS certificate verification failed", str(caught.exception))
            self.assertNotIn("SECRET", str(caught.exception))
            factory.return_value.open.assert_called_once()

    def test_requests_match_provider_contracts(self):
        args = asset.parser().parse_args(["se", "--name", "click", "--prompt", "One click", "--loop"])
        params = elevenlabs.parameters(args)
        url, headers, body = elevenlabs.request(args.prompt, params, True, "fake")
        self.assertIn("output_format=mp3_44100_128", url)
        payload = json.loads(body)
        self.assertNotIn("output_format", payload)
        self.assertEqual(payload["model_id"], "eleven_text_to_sound_v2")
        self.assertTrue(payload["loop"])
        args.type = "bgm"
        params = stable_audio.parameters(args)
        url, headers, body = stable_audio.request(args.prompt, params, True, "fake")
        self.assertIn("stable-audio-2/text-to-audio", url)
        self.assertIn(b"stable-audio-2.5", body)
        self.assertNotIn(b'name="loop"', body)
        boundary = headers["Content-Type"].split("boundary=")[1]
        self.assertTrue(body.endswith(("--" + boundary + "--\r\n").encode()))

    def test_http_errors_are_sanitized_and_not_retried(self):
        for status in [400, 401, 402, 403, 404, 422, 429, 500]:
            with self.subTest(status=status), patch.object(transport.urllib.request, "build_opener") as factory:
                factory.return_value.open.side_effect = urllib.error.HTTPError(
                    "https://example.test", status, "SECRET", {}, io.BytesIO(b"SECRET"))
                with self.assertRaises(transport.GenerationError) as caught:
                    transport.generate("https://example.test", {}, b"{}", 5)
                self.assertNotIn("SECRET", str(caught.exception))
                factory.return_value.open.assert_called_once()

    def test_redirect_never_forwards_credentials(self):
        self.assertIsNone(transport.NoRedirect().redirect_request(None, None, 302, "", {}, "https://other.test"))

    def test_env_precedence_and_no_expansion(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"STABILITY_API_KEY": "environment"}, clear=True):
            root = Path(directory)
            (root / ".env").write_text('STABILITY_API_KEY=file\nELEVENLABS_API_KEY="literal-value"\n', encoding="utf-8")
            self.assertEqual(config.load_keys(root), {"STABILITY_API_KEY": "environment", "ELEVENLABS_API_KEY": "literal-value"})


if __name__ == "__main__":
    unittest.main()
