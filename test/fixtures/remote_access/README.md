These public, test-only TLS identities are deliberately committed. Never use
these keys in a deployment. The CA and media.test leaf exercise normal trust
and hostname validation, plus certificate pin rejection before HTTP credentials
are sent. Renew the leaf before November 2027 with serverAuth and SAN media.test;
if rotating the CA, update test-ca.crt at the same time.
