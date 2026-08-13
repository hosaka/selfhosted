from pyinfra.operations import apt, server, files

# Configure LINSTOR container. Assumes that linstor-controller and linstor-client
# were already installed via cloud-init and controller service is already running.

