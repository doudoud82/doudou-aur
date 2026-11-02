#!/usr/bin/env python3
# shellcheck disable=SC1071

import base64
import getpass
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PRIMARY_KEY_ID = os.getenv("GPGKEY", "063F6A5182A1B15D")
SIGNING_SUBKEY_ID = os.getenv("GPG_SUBKEY", "46B2F45507CA0D4C")


def run(
    args: list[str],
    *,
    passphrase: str | None = None,
) -> bytes:
    command = ["gpg"]

    if passphrase is not None:
        command.extend([
            "--batch",
            "--yes",
            "--pinentry-mode", "loopback",
            "--passphrase-fd", "0",
        ])

    command.extend(args)

    result = subprocess.run(
        command,
        input=(passphrase + "\n").encode() if passphrase is not None else None,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    return result.stdout


def main() -> None:
    if shutil.which("gpg") is None:
        sys.exit("Error: gpg is not installed.")

    # Ask for the original key passphrase.
    password = getpass.getpass("Original GPG passphrase: ")

    if not password:
        sys.exit("Error: passphrase cannot be empty.")

    with tempfile.TemporaryDirectory(prefix="gpg-ci-") as tmp:
        tmp_path = Path(tmp)
        os.chmod(tmp_path, 0o700)

        export_dir = tmp_path / "export"
        export_dir.mkdir(mode=0o700)

        isolated_home = tmp_path / "gnupg"
        isolated_home.mkdir(mode=0o700)

        # 1. Export public primary key.
        print("[1/5] Exporting public primary key...", file=sys.stderr)

        public_key = run([
            "--export",
            f"{PRIMARY_KEY_ID}!",
        ])

        if not public_key:
            sys.exit("Error: public key export failed.")

        public_file = export_dir / "public.gpg"
        public_file.write_bytes(public_key)

        # 2. Export protected signing subkey.
        print("[2/5] Exporting signing subkey...", file=sys.stderr)

        secret_key = run(
            [
                "--export-secret-subkeys",
                f"{SIGNING_SUBKEY_ID}!",
            ],
            passphrase=password,
        )

        if not secret_key:
            sys.exit("Error: secret subkey export failed.")

        secret_file = export_dir / "secret.gpg"
        secret_file.write_bytes(secret_key)

        # 3. Import into isolated GPG home.
        print("[3/5] Importing keys into isolated GPG directory...", file=sys.stderr)

        run([
            "--homedir", str(isolated_home),
            "--import", str(public_file),
        ])

        run(
            [
                "--homedir", str(isolated_home),
                "--import", str(secret_file),
            ],
            passphrase=password,
        )

        # 4. Remove signing subkey passphrase.
        print("\n[4/5] Remove signing subkey passphrase.", file=sys.stderr)

        print("""
In the GPG editor:

  1. Select the signing subkey: key 1
  2. Run: passwd
  3. Enter the current passphrase.
  4. Leave the NEW passphrase empty.
  5. Confirm the empty passphrase.
  6. Run: save

Note: GPG may report 'No secret key' or 'Key not changed'.
We will verify signing capability afterward.
""", file=sys.stderr)

        subprocess.run([
            "gpg",
            "--homedir", str(isolated_home),
            "--edit-key", PRIMARY_KEY_ID,
        ], check=False)

        # Verify signing with an empty passphrase.
        print("\nVerifying signing subkey...", file=sys.stderr)

        test_signature = tmp_path / "test.sig"

        test = subprocess.run(
            [
                "gpg",
                "--homedir", str(isolated_home),
                "--batch",
                "--yes",
                "--pinentry-mode", "loopback",
                "--passphrase-fd", "0",
                "--local-user", f"{SIGNING_SUBKEY_ID}!",
                "--detach-sign",
                "--output", str(test_signature),
            ],
            input=b"\n",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        if test.returncode != 0:
            sys.exit(
                "Error: signing subkey is not usable without a passphrase.\n"
                + test.stderr.decode(errors="replace")
            )

        print("Signing subkey verified without a passphrase.", file=sys.stderr)

        # 5. Export unprotected signing subkey as ASCII armor.
        print("\n[5/5] Exporting unprotected signing subkey...", file=sys.stderr)

        final_key = run(
            [
                "--homedir", str(isolated_home),
                "--armor",
                "--export-secret-subkeys",
                f"{SIGNING_SUBKEY_ID}!",
            ],
            passphrase="",
        )

        if not final_key:
            sys.exit("Error: final secret subkey export failed.")

        # Base64-encode the ASCII-armored key.
        encoded = base64.b64encode(final_key).decode("ascii")

        print("\n" + "=" * 72, file=sys.stderr)
        print("GITHUB ACTIONS SECRET: GPGKEY_PRIVATE_BASE64", file=sys.stderr)
        print("=" * 72, file=sys.stderr)
        print(encoded)
        print("=" * 72, file=sys.stderr)

        print("\n" + "=" * 72, file=sys.stderr)
        print("GITHUB ACTIONS VARIABLE: GPGKEY", file=sys.stderr)
        print("=" * 72, file=sys.stderr)
        print(PRIMARY_KEY_ID, file=sys.stderr)
        print("=" * 72, file=sys.stderr)

        print("""
Add these to your GitHub repository
(Settings -> Secrets and variables -> Actions):

  1. Secret:   GPGKEY_PRIVATE_BASE64
  2. Variable: GPGKEY
""", file=sys.stderr)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        sys.exit(
            f"\nGPG command failed with exit code {exc.returncode}.\n"
            + (exc.stderr.decode(errors="replace") if exc.stderr else "")
        )
    except KeyboardInterrupt:
        sys.exit("\nInterrupted.")
