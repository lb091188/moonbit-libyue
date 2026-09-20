# Forcing a Relink After Native-Layer Changes

After changing `shim/`, vendor patches, or the libyue version: re-run `scripts/prepare.py`,
then force a relink — otherwise `moon run` reuses the old exe. For the rationale see
[docs/adaptation.md](adaptation.md), "Cross-Platform → Build and Linking".

## Detection

You are affected if the exe's mtime is older than `build/libyue_mbt.a`:

```sh
ls -la --time-style=full-iso \
  _build/native/debug/build/examples/<example>/<example>.exe build/libyue_mbt.a
```

## Handling

```sh
moon clean        # full rebuild
# or delete only the link artifact:
rm _build/native/debug/build/examples/<example>/<example>.exe
```

After handling, the exe's mtime should be newer than `build/libyue_mbt.a`.
