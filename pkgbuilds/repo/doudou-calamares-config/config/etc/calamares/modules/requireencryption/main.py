import libcalamares

def pretty_name():
    return "Checking disk encryption"

def run():
    gs = libcalamares.globalstorage
    for p in gs.value("partitions") or []:
        if (isinstance(p, dict) and p.get("mountPoint") == "/"
                and p.get("luksUuid")):
            return None
    return ("Disk encryption is required",
            "Go back to the partitioning page and enable 'Encrypt system'.")