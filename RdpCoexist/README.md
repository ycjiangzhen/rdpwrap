# RdpCoexist

A small, portable **governance/ops shell** that lets **AnyDesk and RDP run side by
side** (concurrent RDP sessions + local console) on modern Windows — **without
modifying `System32\termsrv.dll` on disk**.

It does *not* reimplement the wrapper. It drives
[`sergiye/rdpWrapper`](https://github.com/sergiye/rdpWrapper) (a portable, .NET
Framework 4.7.2, single-file rewrite of RDP Wrapper that redirects the
`TermService` `ServiceDll` to a non-destructive proxy — `TermWrap` — with a
built-in offset engine) and wraps it with the operational pieces it lacks.

> Approach: stop RDP service → point `TermService` `ServiceDll` at a wrapper in a
> portable folder → set `fDenyTSConnections=0`, `fSingleSessionPerUser=0`,
> `EnableConcurrentSessions=1` → start service. The original `termsrv.dll` is
> **never touched**, so SFC / WRP / Windows Update leave it alone.

## Why a shell (the 5 gaps this closes)

| # | Gap in the bare engine | What this shell adds |
|---|------------------------|----------------------|
| 1 | No license grant → cannot repackage/redistribute the engine binary | Engine is **fetched from its official release** and **SHA256-pinned**; nothing is bundled here (`.gitignore` blocks `*.exe`/`*.dll`) |
| 2 | No self-heal after Windows Update replaces `termsrv.dll` | `-Heal` + a **SYSTEM startup scheduled task**: verify, and only re-install if the listener dropped |
| 3 | Verification is GUI-only | `-Verify` returns a **machine-checkable verdict** (`COEXIST-OK` requires a real listener **and** ≥2 active sessions, not just registry values) |
| 4 | Engine phones home for updates → version drift | Engine is **always** invoked with `-offline`; version is pinned in `config.psd1` |
| 5 | Engine DLL is commonly flagged `HackTool:Win32/RDPWrap` | Idempotent **Defender exclusion** for the engine folder (skipped gracefully if exclusions are policy-locked) |

## Layout

```
RdpCoexist/
├─ RdpCoexist.cmd        self-elevating launcher (UAC)
├─ RdpCoexist.ps1        -Apply | -Revert | -Verify | -Heal | -Status
├─ config.psd1           version pin, SHA256 pin, paths, options
└─ modules/
   ├─ Common.psm1        logging, admin check, GPO-override warning
   ├─ Engine.psm1        download + hash-verify + drive the engine
   ├─ Defender.psm1      idempotent exclusion add/remove
   ├─ Verify.psm1        listener + active-session verdict
   ├─ Heal.psm1          scheduled-task register/unregister
   └─ LocalUser.psm1     optional dedicated RDP account
```
Engine binary, logs, and state live under `%ProgramData%\RdpCoexist\` — never in this repo.

## Usage

1. Edit `config.psd1`. At minimum set **`EngineSha256`** to the hash of the engine
   release you vetted (or run the first `-Apply` with `-TrustOnFirstUse`, which
   prints the observed hash for you to paste back and lock).
2. Run:

```
RdpCoexist.cmd -Apply       :: fetch+verify engine, install, register heal task, verify
RdpCoexist.cmd -Verify      :: print current verdict
RdpCoexist.cmd -Revert      :: uninstall engine, remove task + exclusion
```

`COEXIST-OK` only appears once **two** sessions are actually active (e.g. console +
one RDP), because a listener alone does not prove coexistence.

## Requirements & caveats

- **Admin** required (the launcher elevates).
- **.NET Framework 4.7.2** — built into supported Windows 10/11; no install needed.
- **Domain GPO**: if `fSingleSessionPerUser` / `fDenyTSConnections` are enforced by
  policy, they revert on GP refresh. The shell warns; resolve with IT.
- **Same-user dual session** trips license locks in OneDrive/Outlook/Office. Prefer
  the optional dedicated RDP account (`CreateRdpUser`), keeping the console user for AnyDesk.
- **Portability vs. resilience**: the engine is copied under `%ProgramData%` by
  default. Pointing `ServiceDll` at removable media means RDP dies if the media is
  pulled — don't.
- Concurrent-session enablement changes the effective RDP session limit; confirm your
  own licensing position before use.

## Configuration keys

See `config.psd1` for the annotated list. Values shipped here are **neutral
placeholders** — set the version pin, hash pin, and (if used) the RDP user name to
your own before running.
