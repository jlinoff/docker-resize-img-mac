#!/bin/bash
#
# Resize the Docker.qcow2 image to the size specified by
# the user on a Mac.
#
# Copyright (c) 2017 by Joe Linoff
# License: MIT Open Source
#

# ================================================================
# Functions
# ================================================================
function helpme() {
    local bn=$(basename $0)
    echo -e "
USAGE
    \x1B[1m$bn [OPTIONS] [IMAGES]\x1B[0m

DESCRIPTION
    This tool resizes your docker image store on the mac keeping
    only the images that you specify.

    It is needed because the docker image store doesn't grow
    automatically which can cause you to run out of space.

    If you do not specify an image size, it will double the
    current size.

    If you do not specify any images, it will delete all of
    the images and resize the container.

OPTION
    -h, --help      This help message.

    -s SIZE, --size SIZE
                    The new image size. It can be larger
                    or smaller than the current image size.
                    If it is not specified, then the current
                    image size is double.
                    This argument is passed directly to
                    qemu-img so it follows the syntax defined
                    for that tool. For example, you can use
                    100G to specify 100GB.

    -V, --version   Print the program version and exit.

EXAMPLE USAGE
    # Example 1: Help
    \$ \x1B[1m$bn -h\x1B[0m

    # Example 2: Version
    \$ \x1B[1m$bn -V\x1B[0m

    # Example 3: Double the size, lose all images.
    \$ \x1B[1m$bn\x1B[0m

    # Example 4: Make the size 100GB, keep the selected images.
    \$ \x1B[1mdocker images\x1B[0m  # list the images, determine which ones to keep
    \$ \x1B[1m$bn -s 100G img1 img2 img3\x1B[0m

LICENSE
    Copyright (c) 2017 by Joe Linoff
    MIT Open Source

VERSION
    $VERSION
"
    exit 0
}

function dockerStop() {
    osascript -e 'quit app "Docker"'
    if (( $? )) ; then
        echo -e "\x1B[1;31mERROR\x1B[0;31m: unable to stop docker.\x1B[0m"
        exit 1
    fi
    while docker info >/dev/null 2>&1 ; do
        echo -n '.'
        sleep 0.5
    done
    echo ''
}

function dockerStart() {
    docker images >/dev/null 2>&1
    if (( $? )) ; then
        # docker isn't running, start it
        open -a Docker
        if (( $? )) ; then
            echo -e "\x1B[1;31mERROR\x1B[0;31m: unable to start docker.\x1B[0m"
            exit 1
        fi
    fi
    until docker info >/dev/null 2>&1 ; do
        echo -n '.'
        sleep 0.5
    done
    echo ""
}

function dockerRunning() {
    docker images >/dev/null 2>&1
    return $?
}

# ================================================================
# Main
# ================================================================
# Grab command line arguments.
readonly VERSION='0.1.0'
SIZE=''
DOCKER_IMG_FILE="$HOME/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/Docker.qcow2"
IMAGES=()
while (( $# )) ; do
    arg=$1
    shift
    case "$arg" in
        -f|--file)
            DOCKER_IMG_FILE="$1"
            shift
            ;;
        -h|--help)
            helpme
            ;;
        -s|--size)
            # Passed directly to qemu-img.
            SIZE="$1"
            shift
            ;;
        -V|--version)
            bn=$(basename $0)
            echo "$bn v$VERSION"
            exit 0
            ;;
        -*)
            echo -e "\x1B[1;31mERROR\x1B[0;31m: unrecognized option '$arg'.\x1B[0m"
            exit 1
            ;;
        *)
            IMAGES+=($arg)
            ;;
    esac
done

# Verify that the qemu-img tool is available.
if ! qemu-img --version >/dev/null 2>&1 ; then
    echo -e "\x1B[1;31mERROR\x1B[0;31m:${LINENO}: qemu-img not found.\x1B[0m"
    echo "       Please install it using brew or macports and try again."
    exit 1
fi

# Verify that the Docker file is present.
# Note that I use $HOME instead of tilde to avoid expansion issues.
DOCKER_IMG_FILE_EXISTS=1
if [ ! -f $DOCKER_IMG_FILE ] ; then
    echo -e "\x1B[1;32mWARNING\x1B[0;32m:${LINENO}: docker image file not found.\x1B[0m"
    echo "         File: $DOCKER_IMG_FILE"
    echo "         No images can be restored."
    IMAGES=()
    DOCKER_IMG_FILE_EXISTS=0
fi

if (( DOCKER_IMG_FILE_EXISTS )) ; then
    # Check the image format.
    IMG_FORMAT=$(qemu-img info $DOCKER_IMG_FILE 2>&1 | grep -i 'file format:' | awk '{print $3}')
    if ! [[ "$IMG_FORMAT" == "qcow2" ]] ; then
        echo -e "\x1B[1;31mERROR\x1B[0;31m:${LINENO}: qemu-img format not qcow2.\x1B[0m"
        qemu-img info $DOCKER_IMG_FILE
        exit 1
    fi
    echo "INFO:${LINENO}: Image format: $IMG_FORMAT"

    # Get the image size.
    IMG_SIZE=$(qemu-img info $DOCKER_IMG_FILE 2>&1 | grep -i 'virtual size:' | awk -F'(' '{print $2}' | awk '{print $1}')
    printf "INFO:%d: Image virtual size: %'.f bytes\n" $LINENO $IMG_SIZE

    # Set the image size.
    if [[ $SIZE = "" ]] ; then
        (( SIZE = 2 * IMG_SIZE ))
    fi

    # Report the new image size.
    if echo "$SIZE" | grep -q '^[0-9]*$' >/dev/null ; then
        # Only commaize if it is a number.
        printf "INFO:%d: Updated image size: %'.f\n" $LINENO $SIZE
    else
        # Could commaize here by splitting out the digits
        # portion but it isn't worth it.
        printf "INFO:%d: Updated image size: %s\n" $LINENO $SIZE
    fi

    # Make sure that docker is running.
    if (( dockerRunning )) ; then
        echo -n "INFO:${LINENO}: Starting docker"
        dockerStart
    fi

    # This can only be true of the image file exists.
    echo "INFO:${LINENO}: ${#IMAGES[@]} images specified"
    if (( ${#IMAGES[@]} > 0 )) ; then
        # Backup the specified images.
        for IMG in ${IMAGES[@]} ; do
            FN=$(echo -n "$IMG" | base64)
            echo "INFO:${LINENO}:    Saving image $IMG to $FN.tar."
            time docker save -o ${FN}.tar ${IMG}
            if (( $? )) ; then
                echo -e "\x1B[1;31mERROR\x1B[0;31m:${LINENO}: image not found: '$IMG'.\x1B[0m"
                exit 1
            fi
        done
    fi
fi

# Quit docker.
# CITATION: https://blog.mrtrustor.net/post/clean-docker-for-mac (how to stop docker!)
if (( dockerRunning )) ; then
    echo -n "INFO:${LINENO}: Quitting docker"
    dockerStop
fi

# Resize the image.
if [ -f $DOCKER_IMG_FILE ] ; then
    echo "INFO:${LINENO}: Removing the image file."
    rm -f $DOCKER_IMG_FILE
fi

echo "INFO:${LINENO}: Re-creating the image file."
time qemu-img create -f qcow2 $DOCKER_IMG_FILE $SIZE
if (( $? )) ; then
    echo -e "\x1B[1;31mERROR\x1B[0;31m:${LINENO}: Could not create the docker image file.\x1B[0m"
    exit 1
fi

# Restart docker.
echo -n "INFO:${LINENO}: Restarting docker"
dockerStart

if (( ${#IMAGES[@]} > 0 )) ; then
    # Re-populate the images.
    echo "Re-populate the docker images."
    for IMG in ${IMAGES[@]} ; do
        FN=$(echo -n "$IMG" | base64)
        echo "INFO:${LINENO}:    Saving image $IMG to $FN.tar."
        time docker load -q -i ${FN}.tar
        if (( $? )) ; then
            echo -e "\x1B[1;32mWARNING\x1B[0;32m:${LINENO}: Docker image not restored: '$FN.tar'.\x1B[0m"
        fi
    done

    echo "Cleaning up."
    for IMG in ${IMAGES[@]} ; do
        FN=$(echo -n "$IMG" | base64)
        echo "INFO:${LINENO}:    Deleting $FN.tar."
        rm -f $FN.tar
    done
fi

echo "Done."
