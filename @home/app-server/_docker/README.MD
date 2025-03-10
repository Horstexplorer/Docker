# Docker configuration
###### System preparations

### Apply [etc/docker/deamon.json](./deamon.json)  
Features:
- Enabled IPv6 support so that requests coming from an IPv& connection don`t get translated and become meaningless
- Configures Nvidia runtime (this obviously requires the system to have an Nvidia GPU installed)

### Install Nvidia Toolkit
Luckily there is a guide to follow [here](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).