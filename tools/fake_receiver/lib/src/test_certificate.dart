/// The fake receiver's TLS identity: a self-signed certificate for
/// `fake-receiver.test`, as real Cast devices present a self-signed one.
///
/// Test-only. Nothing trusts it, it guards nothing, and the key is public
/// on purpose: the app's client accepts any certificate (docs/04), so this
/// only lets the fake speak TLS on 127.0.0.1. Made with
/// `openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1
/// -nodes -days 36500 -subj /CN=fake-receiver.test`.
library;

const testCertificate = '''
-----BEGIN CERTIFICATE-----
MIIBkDCCATegAwIBAgIUXensHOGGW7wWj6o/Dvkdwl9UV3EwCgYIKoZIzj0EAwIw
HTEbMBkGA1UEAwwSZmFrZS1yZWNlaXZlci50ZXN0MCAXDTI2MTAwMjA1NDAzNVoY
DzIxMjYwOTA4MDU0MDM1WjAdMRswGQYDVQQDDBJmYWtlLXJlY2VpdmVyLnRlc3Qw
WTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAT8LI8WHODRFhwPuSrdzzlIUuR7H79i
hgD49wkXwKnfYoEGtGxkPW3OVWJayE9fm7ZJgIFfmPDHGmVR9liv5O3Vo1MwUTAd
BgNVHQ4EFgQUzzONORgtG99JW+wvlCG/3x7dfQ0wHwYDVR0jBBgwFoAUzzONORgt
G99JW+wvlCG/3x7dfQ0wDwYDVR0TAQH/BAUwAwEB/zAKBggqhkjOPQQDAgNHADBE
AiBu1Mvb5Qj++uuv687gsEFh+ikLgHB3GosQHE1k58u9gwIgLANBt0dMn2nDRuJn
PTEmgJdSl5vvQ/Ah/KAMdatqh9E=
-----END CERTIFICATE-----
''';

const testPrivateKey = '''
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgLA/tR/xgjKRcW3E0
yoLJyPg/OmBPB0nZg6IP4zUZK8yhRANCAAT8LI8WHODRFhwPuSrdzzlIUuR7H79i
hgD49wkXwKnfYoEGtGxkPW3OVWJayE9fm7ZJgIFfmPDHGmVR9liv5O3V
-----END PRIVATE KEY-----
''';
