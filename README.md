# docker-resize-img-mac
Resize the Docker.qcow2 image on the Mac.

This tool resizes your docker image store on the mac keeping only the images that you specify.

It is useful because the docker image store doesn't grow automatically which can cause you to run out of space.

If you do not specify an image size, it will double the current size.

If you do not specify any images, it will delete all of the images and resize the image store.

You must have `qemu-img` installed for it to work. The `qemu` tools are available from the homebrew and macports projects.

Here is how you use this tool.

```bash
$ docker-resize-img-mac.sh -s 194G img1 img2 img3
```

To see the updated image information.
```bash
$ qemu-img info ~/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/Docker.qcow2 
image: /Users/jlinoff/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/Docker.qcow2
file format: qcow2
virtual size: 194G (208305913856 bytes)
disk size: 196K
cluster_size: 65536
Format specific information:
    compat: 1.1
    lazy refcounts: false
    refcount bits: 16
    corrupt: false
```

Here is how you download it.

```bash
$ git clone https://github.com/jlinoff/docker-resize-img-mac.git
$ cp docker-resize-img-mac/docker-resize-img-mac.sh ~/bin/
```
