import libcalamares


def pretty_name():
    return "Installing packages"


def names_from(operations, action):
    out = []
    for op in operations or []:
        if not isinstance(op, dict):
            continue
        for entry in op.get(action) or []:
            if isinstance(entry, str):
                out.append(entry)
            elif isinstance(entry, dict) and isinstance(entry.get("package"), str):
                out.append(entry["package"])
    return out


def run():
    gs = libcalamares.globalstorage
    conf = libcalamares.job.configuration or {}

    # packages.conf-style operations, plus everything the choosers queued
    ops = list(conf.get("operations") or [])
    if gs.contains("packageOperations"):
        ops += list(gs.value("packageOperations") or [])

    install = list(dict.fromkeys(names_from(ops, "install")))
    try_install = [p for p in dict.fromkeys(names_from(ops, "try_install"))
                   if p not in install]

    if not install:
        return None

    libcalamares.utils.debug(
        f"Installing {len(install)} packages in one transaction: {' '.join(install)}")

    sync = "-Sy" if conf.get("update_db", True) else "-S"
    cmd = ["pacman", sync, "--noconfirm", "--noprogressbar", "--needed"] + install

    rc = 1
    for attempt in range(1, int(conf.get("num_retries", 3)) + 1):
        rc = libcalamares.utils.target_env_call(cmd)
        if rc == 0:
            break
        libcalamares.utils.warning(f"pacman attempt {attempt} failed with {rc}")
    if rc != 0:
        return ("Package installation failed",
                f"pacman exited with code {rc}. See the Calamares log.")

    if try_install:
        rc = libcalamares.utils.target_env_call(
            ["pacman", "-S", "--noconfirm", "--noprogressbar", "--needed"] + try_install)
        if rc != 0:
            libcalamares.utils.warning("Optional packages failed to install; continuing.")

    return None