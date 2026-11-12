# SMB playback read tuning

The App pins the OpenPlayX `smb_connect` fork to an immutable Git commit in
`pubspec.yaml` / `pubspec.lock`. Fetching this private dependency requires
GitHub SSH access. The fork retains the original history, attribution and
license; its changes are on `feature/smb-read-tuning`.

`SmbAccess` continues using `SmbConnect.connectAuth()` and the playback gateway
uses outputs of up to 256 KiB. SMB playback now opts into
[progressive startup/seek reads](smb_progressive_reads.md), starting with a
64 KiB output. The fork's maximum internal buffer remains
1 MiB per open file, with real large-MTU SMB2 READ requests bounded by server
limits and credits. Smaller requests are used for servers without multi-credit
support. No unbounded concurrent prefetching is introduced.

On 2026-11-12, a real 3,086,012,704-byte movie was read from offset 1 GiB through
the Mac App-equivalent client, VLESS/TLS, Relay HAProxy/sing-box/frps and Home
sing-box/frpc/SMB. The original published package achieved 2.38 MB/s; the tuned
fork with the App's resolved dependencies, including pointycastle 4, read a
256 MiB range in 29.127 seconds: **9.22 MB/s**, about **3.9 times** the baseline.

The selected parameter was compared against 256 KiB (6.10 MB/s) and 512 KiB
(7.46 MB/s) caps. Checks covered a continuous 16 MiB range, non-aligned seeks,
cached forward/backward seeks, last-file bytes and EOF. The checksums matched
Home-local reads. The benchmark excludes the HTTP gateway, decoding and an
actual phone's CPU/network; installed Apps need a rebuild to use the new code.

The library contains a reproducible `tool/read_benchmark.dart` and detailed
results in `docs/read_tuning.md`. Credentials belong in private files outside
the repository and must not be exported to Relay for benchmarking.
