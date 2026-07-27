from pyinfra.operations import apt, server, files

apt.ppa(
    name="Add LINBIT DRBD9 stack PPA",
    src="ppa:linbit/linbit-drbd9-stack",
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
    "incus-1": "10.10.0.79",
    "incus-2": "10.10.0.71",
    "incus-3": "10.10.0.154",
}.items():
    server.shell(
        name=f"Register satellite {node}",
        commands=[
            f"linstor node list | grep -q {node} || "
            f"linstor node create {node} {ip} --node-type satellite"
        ],
    )

for node in ["incus-1", "incus-2", "incus-3"]:
    server.shell(
        name=f"Create nvme_pool on {node}",
        commands=[
            f"linstor storage-pool list | grep -q {node}.*nvme_pool || "
            f"linstor physical-storage create-device-pool --storage-pool nvme_pool "
            f"--pool-name nvme_pool zfsthin {node} /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1"
        ],
    )
