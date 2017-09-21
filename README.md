[![Releases](https://img.shields.io/github/release/jlinoff/docker-resize-img-mac.svg?style=flat)](https://github.com/jlinoff/docker-resize-img-mac/releases)

# docker-resize-img-mac
Resize the Docker.qcow2 image on the Mac.

This tool resizes your docker image store on the mac keeping only the images that you specify.

It is useful because the docker image store doesn't grow automatically which can cause you to run out of space.
> This no longer appears to be true. Recently my image repository grew to over 700GB under docker 17.06. When I deleted almost all of the images using `docker rmi`, it did not shrink. After I ran this tool over the update system, it reduced the disk usage to about 100GB.

If you do not specify an image size, it will double the current size.

If you do not specify any images, it will delete all of the images and resize the image store.

You must have `qemu-img` installed for it to work. The `qemu` tools are available from the homebrew and macports projects.

### Getting help
Here is how you get help.

```bash
$ docker-resize-img-mac.sh -h
```

### Resize the image repository
Here is how I used the tool resize the image repository to 120G and keep _all of my images_ (`-a`), except for the `<none>` images.

```bash
$ ./docker-resize-img-mac.sh -s 120G -a
```

Here is an example that resizes the repository and only carries over a few
specified images. All other images are lost.

```bash
$ docker-resize-img-mac.sh -s 194G centos:6 centos:7 ubuntu:latest alpine:latest $USER/my-cool-image
```

### Backing up your image repository (-b)
Here is how you backup your image repository using this tool.

```bash
$ docker-resize-img-mac.sh -b -a
```

The contents are put in `backup/TIMESTAMP` along with a `restore.sh` script that will restore the images.

You can also specify specific images to backup.

> Although this tool was not originally written with backup in mind, this feature has become very useful for guaranteeing that no information is lost.

Added new tool called `docker-backup.sh` to back images in any docker environment that supports bash scripts.

### How to observe the improvements
After running it, the docker.qcow2 image was reduced signficantly. Apparently there is a lot of wasted space.

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

### Downloading it
Here is how you download it.

```bash
$ git clone https://github.com/jlinoff/docker-resize-img-mac.git
$ cp docker-resize-img-mac/docker-resize-img-mac.sh ~/bin/
$ cp docker-resize-img-mac/docker-backup.sh ~/bin/
$ chmod 0755 ~/bin/docker-resize-img-mac/docker-resize-img-mac.sh ~/bin/docker-backup.sh
```
