from pyinfra.operations import apt, server, files

files.download(
    name="Fetch LINBIT signing key",
    src="https://packages.linbit.com/package-signing-pubkey.asc",
    dest="/etc/apt/keyrings/linbit.asc",
)

files.put(
    name="Add LINBIT repo",
    src="files/linbit.sources",
    dest="/etc/apt/sources.list.d/linbit.sources",
)

apt.packages(
    name="Install LINSTOR controller and client",
    packages=["linstor-controller", "linstor-client", "python3-setuptools"],
    update=True,
)

server.service(
    name="Enable linstor-controller",
    service="linstor-controller",
    running=True,
    enabled=True,
)

for node, ip in {
    "node-1": "10.10.0.101",
    "node-2": "10.10.0.102",
    "node-3": "10.10.0.103",
}.items():
    server.shell(
        name=f"Register satellite {node}",
        commands=[
            f"linstor node list | grep -q {node} || "
            f"linstor node create {node} {ip} --node-type satellite"
        ],
    )

# for node in ["node-1", "node-2", "node-3"]:
#     server.shell(
#         name=f"Create nvme_pool on {node}",
#         commands=[
#             f"linstor storage-pool list | grep -q {node}.*nvme_pool || "
#             f"linstor physical-storage create-device-pool --storage-pool nvme_pool "
#             f"--pool-name nvme_pool zfsthin {node} /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1"
#         ],
#     )
