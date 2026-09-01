# LNURLw Testing Guide

This document covers how the LNURLw (Boltcard / LUD-17) feature works, what is tested automatically, and how to run a full end-to-end test manually.

---

## How LNURLw works in this app

A Boltcard tap produces a raw-scheme URI like:

```
lnurlw://pay.example.com/withdraw?k1=<random-hex>
```

The app handles this via two paths:

### Path 1 — Deep link (NFC / tapped URL)

`deep_link_handler.dart` catches `lnurlw://` URLs from the OS and converts them to `https://` (or `http://` for local/onion hosts). `app.dart` then shows a host-approval dialog naming the target host before any network call, and on approval hands the URL to `openLnurlWithdraw` (`number_pad.dart`), which fetches the params and opens the number pad in withdraw mode.

The scheme must be registered with the OS for this path to fire: `android/app/src/main/AndroidManifest.xml` (browsable VIEW filter *and* the NFC `NDEF_DISCOVERED` filter), `ios/Runner/Info.plist`, and `macos/Runner/Info.plist`.

### Path 2 — Scanner / paste (new)

`parse.rs` (`lnurlw_to_http`) detects `lnurlw://` in scanned or pasted text (case-insensitively), performs the same scheme conversion, and returns `ParsedText::LnurlWithdraw(url)`. `scan.dart` handles this variant by calling `openLnurlWithdraw` — the same entry point as the deep link, but **without** the host-approval dialog, since aiming the camera at a code is already the user choosing that server. This path works on Linux desktop as well as Android.

### Scheme conversion rules

| Host | Scheme used |
|---|---|
| `localhost` | `http` |
| `127.0.0.1` | `http` |
| `10.0.2.2` (Android emulator) | `http` |
| `*.onion` | `http` |
| Everything else | `https` |

### Flow once the URL is received

1. App GETs `{url}` — server responds with withdraw params JSON (`tag`, `callback`, `k1`, `minWithdrawable`, `maxWithdrawable`)
2. User confirms the amount
3. App creates a Lightning invoice via the Fedimint federation + gateway
4. App GETs `{callback}?k1={k1}&pr={invoice}`
5. Server pays the invoice and responds `{"status":"OK"}`
6. App calls `await_receive` and shows success when ecash lands

---

## What is tested automatically (CI)

### Rust unit tests — `cargo test`

**`rust/ecashapp/src/lib.rs`** (existing):
- `test_parse_valid_withdraw_response` — valid params JSON parsed correctly
- `test_parse_withdraw_response_missing_description_defaults_empty`
- `test_parse_withdraw_response_server_error`
- `test_parse_withdraw_response_wrong_tag`
- `test_parse_withdraw_response_missing_callback`
- `test_callback_url_no_existing_params` — `build_lnurlw_callback_url` appends `?k1=&pr=`
- `test_callback_url_with_existing_params` — appends `&k1=&pr=` when query string exists

**`rust/ecashapp/src/parse.rs`** (new):
- `lnurlw_to_http_normal_host_uses_https`
- `lnurlw_to_http_localhost_uses_http`
- `lnurlw_to_http_loopback_uses_http`
- `lnurlw_to_http_android_emulator_uses_http`
- `lnurlw_to_http_onion_uses_http`
- `lnurlw_to_http_wrong_scheme_returns_none`
- `lnurlw_to_http_uppercase_scheme_is_accepted`
- `lnurlw_to_http_uppercase_local_host_uses_http`
- `lnurlw_to_http_short_input_returns_none`
- `lnurlw_uri_returns_lnurl_withdraw_variant` — scanner returns `LnurlWithdraw` with correct URL
- `lnurlw_uri_with_selected_federation_uses_it`

### Flutter unit tests — `flutter test`

**`test/deep_link_parser_test.dart`** (existing):
- `lnurlw: scheme (LUD-17)` group — 6 cases covering scheme conversion for all host types

### What is NOT covered automatically

- The full payment flow (invoice creation → gateway payment → ecash receipt) requires a live Fedimint federation and gateway. See the manual test section below.

---

## Manual end-to-end testing

### Prerequisites

1. App built and running (Linux desktop or Android device/emulator)
2. At least one Fedimint federation joined with a working Lightning gateway
3. A Fedimint gateway accessible from your machine with its URL and password

### Option A — Scanner / paste (no boltcard, no NFC)

This tests the new scanner path and works on Linux desktop.

1. Run the app (`just run` for Linux)
2. Open the scanner or paste field
3. Paste any `lnurlw://` URI — you can use the test server below to generate one, or any real LNURLw endpoint

### Option B — Full end-to-end with real payment via test server

`scripts/test-lnurlw/` is a standalone Rust binary that:
- Starts a local LNURLw mock server
- Fires a `lnurlw://` deep link to the running app
- Validates the protocol handshake (k1 match, bolt11 format)
- Pays the invoice through your Fedimint gateway's `/pay_invoice_for_operator` endpoint
- Exits 0 if ecash is on its way, 1 on any failure

#### Build and run (macOS desktop app)

```bash
cd scripts/test-lnurlw
cargo run -- \
  --gateway-url http://localhost:8175 \
  --gateway-password <your-gateway-password>
```

#### Build and run (Android — device connected via ADB)

```bash
cd scripts/test-lnurlw
cargo run -- \
  --gateway-url http://localhost:8175 \
  --gateway-password <your-gateway-password> \
  --android
```

The `--android` flag fires the deep link via `adb shell am start` and substitutes `10.0.2.2` as the server host so the emulator can reach your machine.

#### What to expect

```
Mock LNURLw server listening on port 54321
k1              : a3f8...
LNURLw endpoint : http://127.0.0.1:54321/lnurlw
Callback        : http://127.0.0.1:54321/callback
Deep link       : lnurlw://127.0.0.1:54321/lnurlw
Gateway         : http://localhost:8175

Deep link fired — waiting for app to respond (timeout: 60s)…
← GET /lnurlw from 127.0.0.1:...
→ serving LNURLw params
← GET /callback from 127.0.0.1:...
✓ k1 matched
✓ bolt11 received: lnbcrt100n1p...
  paying invoice via gateway…
✓ gateway accepted payment

✓ Test passed — LNURLw withdraw flow completed successfully.
  Invoice paid: lnbcrt100n1p...
```

The app should transition from the "Waiting for payment…" screen to the success screen and ecash should appear in your balance.

### Option C — Physical iPhone

iOS reads `CFBundleURLTypes` at **install** time, so a hot reload will not pick up a
scheme change. Reinstall first:

```bash
just run-ios-device        # or scripts/run-ios-device.sh
```

Leave that console open. `DeepLinkHandler` logs `Deep link cold start:` /
`Deep link warm start:` (payload redacted) on every delivery — that line is the ground
truth for whether iOS actually handed the URL to the app. If the scheme still doesn't
take, delete the app from the phone and re-run; LaunchServices occasionally caches the
old registration.

#### C1 — Registration and routing (no server, ~30 seconds)

1. On the iPhone, open **Shortcuts** → new shortcut → add the **Open URLs** action.
2. Set the URL to `lnurlw://example.com/withdraw?k1=deadbeefdeadbeef` and run it.

Expected: the app launches or foregrounds → federation picker (if more than one
federation is joined) → the **"Contact this server?"** dialog naming `example.com`.
Tap **Cancel** and nothing is fetched. Tapping **Contact server** ends in a "Failed to
process payment link" toast because `example.com` is not an LNURLw endpoint — that
failure still proves the path, since it can only happen after the URL reached Dart.

Use Shortcuts rather than Safari's address bar: Safari treats a typed custom scheme as a
search. A real anchor does work, so for the Safari path serve one from your Mac:

```bash
cd "$(mktemp -d)" && \
  printf '<a href="lnurlw://example.com/withdraw?k1=deadbeef">tap me</a>' > index.html && \
  python3 -m http.server 8000
```

then open `http://$(ipconfig getifaddr en0):8000` on the phone and tap the link.

Repeat in all three launch states: app not running (cold start, exercises
`getInitialLink()` under the scene lifecycle), backgrounded (warm start via
`uriLinkStream`), and already foregrounded.

#### C2 — Full withdraw with a real payment

The harness above is not usable from a physical iPhone: its mock server is plain HTTP
bound to `127.0.0.1`, which the phone cannot reach, and any LAN IP host gets rewritten to
`https://` by the LUD-17 rules (only `localhost`, `127.0.0.1`, `10.0.2.2` and `.onion`
stay HTTP). Either:

- Run the harness on **macOS** or **Android**, where it already works. The protocol
  handshake, invoice creation, gateway payment and `await_receive` are all
  platform-independent; the iOS-specific delta is purely URL delivery, which C1 covers.
- Or use a real https LNURLw source on the phone — an LNbits instance with the Boltcard
  extension emits the raw `lnurlw://` form. (LNbits' plain withdraw QR is bech32
  `LNURL1…`, which is the scanner path, not this deep link.)

Fronting the harness with an https tunnel is possible but racy: it binds a random port
and starts a 60-second timeout the moment it fires the link. `--public-host` / `--no-fire`
flags would make that route practical.

#### Known iOS limitation

A Boltcard NFC **tap** will not launch the app on iOS. Background NFC tag dispatch only
reaches apps through Associated Domains (https NDEF records), and this app has no
entitlements file. On iOS, `lnurlw:` links arrive from other apps and web pages only; an
in-app `NFCNDEFReaderSession` would be a separate feature.

### Finding your gateway URL and password

If you're running `devimint` locally:

```bash
# Gateway URL is typically:
http://localhost:8175

# Password is set when starting gatewayd, or found via:
cat /tmp/devimint-env/gatewayd.env | grep FM_GATEWAY_PASSWORD
```

---

## Code locations

| File | What it does |
|---|---|
| `rust/ecashapp/src/parse.rs` | `lnurlw_to_http()` + `ParsedText::LnurlWithdraw` detection in `parse_text` |
| `rust/ecashapp/src/lib.rs` | `ParsedText::LnurlWithdraw(String)` variant + `fetch_lnurl_withdraw` + `execute_lnurl_withdraw` |
| `lib/deep_link_handler.dart` | OS deep link → `DeepLinkType.lnurlWithdraw` (NFC / tapped URL path) |
| `lib/app.dart` | `_handleDeepLink` — host-approval dialog, then `openLnurlWithdraw` |
| `lib/number_pad.dart` | `openLnurlWithdraw()` — fetch params, then number pad in withdraw mode |
| `lib/lnurl_withdraw.dart` | `LnurlWithdrawWaiting` — invoice → callback → `awaitReceive` |
| `lib/scan.dart` | `ParsedText_LnurlWithdraw` case → `openLnurlWithdraw` |
| `ios/Runner/Info.plist`, `macos/Runner/Info.plist`, `android/.../AndroidManifest.xml` | `lnurlw` scheme registration |
| `test/deep_link_parser_test.dart` | Deep link scheme conversion tests |
| `scripts/test-lnurlw/` | End-to-end test harness with real gateway payment |
