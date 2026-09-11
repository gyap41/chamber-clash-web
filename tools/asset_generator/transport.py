"""Single POST, no redirects/retries, bounded response, sanitized failures."""
import os
import socket
import ssl
import sys
import time
import urllib.error
import urllib.request

USER_AGENT = "ChamberClashAssetGenerator/1.0 (Python urllib)"

class GenerationError(Exception):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def tls_context():
    """Avoid Windows' cached intermediate CA certificates; retain full verification."""
    if sys.platform != "win32":
        return ssl.create_default_context()
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    roots = [ssl.DER_cert_to_PEM_cert(cert)
             for cert, encoding, trust in ssl.enum_certificates("ROOT")
             if encoding == "x509_asn" and
             (trust is True or ssl.Purpose.SERVER_AUTH.oid in trust)]
    if not roots:
        raise GenerationError("No trusted Windows server-auth roots available. No request sent.")
    context.load_verify_locations(cadata="".join(roots))
    # Explicit additional trust is opt-in; never load the Windows CA cache.
    cafile = os.environ.get("SSL_CERT_FILE") or None
    capath = os.environ.get("SSL_CERT_DIR") or None
    if cafile or capath:
        context.load_verify_locations(cafile=cafile, capath=capath)
    return context


def https_opener():
    try:
        opener = urllib.request.build_opener(
            NoRedirect(), urllib.request.HTTPSHandler(context=tls_context()))
        # Identify the actual application; Stability rejects urllib's generic default.
        opener.addheaders = [("User-Agent", USER_AGENT)]
        return opener
    except (OSError, ValueError):
        raise GenerationError("TLS trust configuration failed. No request sent; details hidden.") from None


def generate(url, headers, body, timeout):
    request = urllib.request.Request(url, data=body, headers=headers, method="POST")
    opener = https_opener()
    started = time.monotonic()
    try:
        with opener.open(request, timeout=timeout) as response:
            if response.status != 200:
                raise GenerationError("Unexpected HTTP status; stopped without retry.")
            if response.headers.get_content_type() not in (
                    "audio/wav", "audio/x-wav", "audio/wave", "audio/vnd.wave", "audio/mpeg", "application/octet-stream"):
                raise GenerationError("Unexpected response format; response body hidden.")
            chunks, size = [], 0
            while True:
                if time.monotonic() - started > timeout:
                    raise GenerationError("Download deadline exceeded; generation outcome uncertain. No retry.")
                chunk = response.read1(64 * 1024)
                if not chunk:
                    break
                size += len(chunk)
                if size > 80 * 1024 * 1024:
                    raise GenerationError("Audio exceeds 80 MiB safety limit. No retry.")
                chunks.append(chunk)
            return b"".join(chunks)
    except urllib.error.HTTPError as exc:
        reasons = {400: "invalid parameter", 401: "authentication failed", 402: "payment/credits required",
                   403: "permission or moderation rejection", 404: "endpoint/model unavailable",
                   422: "request rejected / invalid parameter", 429: "rate/concurrency limit",
                   500: "provider internal error", 503: "provider unavailable"}
        # Never print server bodies, arbitrary headers, URLs, or exception text.
        raise GenerationError(f"HTTP {exc.code}: {reasons.get(exc.code, 'request failed')}. No retry.") from None
    except (socket.timeout, TimeoutError):
        raise GenerationError("Timeout; generation/charge outcome uncertain. No retry.") from None
    except (urllib.error.URLError, OSError) as exc:
        reason = exc.reason if isinstance(exc, urllib.error.URLError) else exc
        if isinstance(reason, ssl.SSLCertVerificationError):
            raise GenerationError("TLS certificate verification failed. Check trust chain and clock. No retry.") from None
        raise GenerationError("Network/TLS/proxy failure; generation outcome uncertain. No retry.") from None
