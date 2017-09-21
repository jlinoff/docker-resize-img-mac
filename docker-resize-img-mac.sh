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
    ${B}$bn [OPTIONS] [IMAGES]${R}

DESCRIPTION
    This tool resizes your docker image store on the mac keeping
    only the images that you specify.

    It is needed because the docker image store doesn't grow
    automatically which can cause you to run out of space.

    If you do not specify an image size, it will double the
    current size.

    If you do not specify any images, it will delete all of
    the images and resize the container.

OPTIONS
    -a, --all       Save and restore all images.
                    This is the same as specifying the following for
                    the images:
                    ${B}\$(docker images --format '{{.Repository}}:{{.Tag}}')${R}

    -f FILE, --file FILE
                    The docker image file.
                    You should never need to set this.
                    Default: ${B}$DOCKER_IMG_FILE${R}

    -h, --help      This help message.

    -k, --keep      Keep the saved images.
                    Normally the images are deleted but this option
                    keeps them.
                    Be careful, the images can consume a lot of
                    disk space.

    -s SIZE, --size SIZE
                    The new image size. It can be larger or smaller
                    than the current image size.  If it is not
                    specified, then the current image size is double.

                    This argument is passed directly to qemu-img so it
                    follows the syntax defined for that tool. For
                    example, you can use ${B}100G${R} to specify 100GB.

    -V, --version   Print the program version and exit.

EXAMPLE USAGE
    # Example 1: Help
    \$ ${B}$bn -h${R}

    # Example 2: Version
    \$ ${B}$bn -V${R}

    # Example 3: Double the size, lose all images.
    \$ ${B}$bn${R}

    # Example 4: Make the size 100GB, keep the selected images.
    \$ ${B}docker images${R}  # list the images, determine which ones to keep
    \$ ${B}$bn -s 100G img1 img2 img3${R}

    # Example 5: Resize all images the old way.
    \$ ${B}$bn -s 120G \$(docker images --format '{{.Repository}}:{{.Tag}}')${R}

    # Example 6: Resize all images the new way.
    \$ ${B}$bn -s 120G -a${R}

LICENSE
    Copyright (c) 2017 by Joe Linoff
    MIT Open Source

VERSION
    $VERSION
"
    exit 0
}

function dockerRunning() {
    local IMGS=($(docker images -q 2>/dev/null))
    if (( ${#IMGS[@]} )) ; then
        return 0
    else
        return 1
    fi
}

function dockerStop() {
    if dockerRunning ; then
        echo -n "INFO:${LINENO}: Stopping docker."
        osascript -e 'quit app "Docker"'
        if (( $? )) ; then
            echo -e "${RB}ERROR${RN}: unable to stop docker."
            echo -e "       This failure can occur if docker containers are running.${R}"
            exit 1
        fi
        while docker info >/dev/null 2>&1 ; do
            echo -n '.'
            sleep 0.5
        done
        echo ''
        if dockerRunning ; then
            echo -e "${RB}ERROR${RN}: unable to stop docker.${R}"
            exit 1
        fi
    fi
}

function dockerStart() {
    if ! dockerRunning ; then
        # docker isn't running, start it
        echo -n "INFO:${LINENO}: Starting docker."
        open --background -a Docker
        if (( $? )) ; then
            echo -e "${RB}ERROR${RN}: unable to start docker.${R}"
            exit 1
        fi
    fi
    # Wait for it to be ready.
    until docker info >/dev/null 2>&1 ; do
        echo -n '.'
        sleep 0.5
    done
    echo ""
}

# ================================================================
# Main
# ================================================================
# Grab command line arguments.
readonly VERSION='0.4.1'
readonly B=$(printf "\x1B[1m")
readonly R=$(printf "\x1B[0m")
readonly RB=$(printf "\x1B[1;31m")  # red-bold
readonly RN=$(printf "\x1B[0;31m")  # red-normal
readonly GB=$(printf "\x1B[1;32m")  # green-bold
readonly GN=$(printf "\x1B[0;32m")  # green-normal

SIZE=''
DOCKER_IMG_FILE="$HOME/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/Docker.qcow2"
IMAGES=()
KEEP=0

while (( $# )) ; do
    arg=$1
    shift
    case "$arg" in
        -a|--all)
            IMAGES=($(docker images --format '{{.Repository}}:{{.Tag}}'))
            ;;
        -f|--file)
            DOCKER_IMG_FILE="$1"
            shift
            ;;
        -h|--help)
            helpme
            ;;
        -k|--keep)
            KEEP=1
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
            echo -e "${RB}ERROR${RN}: unrecognized option '$arg'.${R}"
            exit 1
            ;;
        *)
            IMAGES+=($arg)
            ;;
    esac
done

# Verify that the qemu-img tool is available.
if ! qemu-img --version >/dev/null 2>&1 ; then
    echo -e "${RB}ERROR${RN}:${LINENO}: qemu-img not found.${R}"
    echo "       Please install it using brew or macports and try again."
    exit 1
fi

# Verify that the Docker file is present.
# Note that I use $HOME instead of tilde to avoid expansion issues.
DOCKER_IMG_FILE_EXISTS=1
if [ ! -f $DOCKER_IMG_FILE ] ; then
    echo -e "${RB}WARNING${RN}:${LINENO}: docker image file not found.${R}"
    echo "         File: $DOCKER_IMG_FILE"
    echo "         No images can be restored."
    IMAGES=()
    DOCKER_IMG_FILE_EXISTS=0
fi

# Get information about the image.
if (( DOCKER_IMG_FILE_EXISTS )) ; then
    # Check the image format.
    IMG_FORMAT=$(qemu-img info $DOCKER_IMG_FILE 2>&1 | grep -i 'file format:' | awk '{print $3}')
    if ! [[ "$IMG_FORMAT" == "qcow2" ]] ; then
        echo -e "${RB}ERROR${RN}:${LINENO}: qemu-img format not qcow2.${R}"
        qemu-img info $DOCKER_IMG_FILE
        exit 1
    fi
    echo "INFO:${LINENO}: Image format: $IMG_FORMAT."

    # Get the image size.
    IMG_SIZE=$(qemu-img info $DOCKER_IMG_FILE 2>&1 | grep -i 'virtual size:' | awk -F'(' '{print $2}' | awk '{print $1}')
    printf "INFO:%d: Image virtual size: %'.f bytes.\n" $LINENO $IMG_SIZE

    # Set the image size.
    if [[ $SIZE = "" ]] ; then
        (( SIZE = 2 * IMG_SIZE ))
    fi

    # Report the new image size.
    if echo "$SIZE" | grep -q '^[0-9]*$' >/dev/null ; then
        # Only commaize if it is a number.
        printf "INFO:%d: Updated image size: %'.f.\n" $LINENO $SIZE
    else
        # Could commaize here by splitting out the digits
        # portion but it isn't worth it.
        printf "INFO:%d: Updated image size: %s.\n" $LINENO $SIZE
    fi

    # Make sure that docker is running.
    if ! dockerRunning ; then
        dockerStart
    fi
fi

# Make sure that no processes are running.
# At this point docker should be running.
if dockerRunning ; then
    PROCS=($(docker ps -a --format '{{.ID}}'))
    if (( ${#PROCS[@]} )) ; then
        echo -e "${RB}ERROR${RN}:${LINENO}: processes are running, please stop them before proceeding.${R}"
        exit 1
    fi
fi

# Save the images while docker is running.
if (( DOCKER_IMG_FILE_EXISTS )) ; then
    # This can only be true of the image file exists.
    n=${#IMAGES[@]}
    echo "INFO:${LINENO}: $n images specified."
    if (( n > 0 )) ; then
        # Backup the specified images.
        i=0
        for IMG in ${IMAGES[@]} ; do
            (( i++ ))
            FN=$(echo -n "$IMG" | base64)
            echo -n "INFO:${LINENO}:    Saving image $i of $n: '$IMG' --> '$FN.tar' "

            # Get the image size.
            SZ=$(docker inspect $IMG | grep '"Size"' | awk -F: '{print $2}' | awk -F, '{print $1}' | awk '{print $1}')
            if (( SZ > 999999999 )) ; then
                SZSTR="$(echo "scale=2 ; $SZ / 1000000000" | bc)GB"
            elif (( SZ > 999999 )) ; then
                SZSTR="$(echo "scale=2 ; $SZ / 1000000" | bc)MB"
            elif (( SZ > 999 )) ; then
                SZSTR="$(echo "scale=2 ; $SZ / 1000" | bc)KB"
            fi
            echo "($SZSTR)."

            # Now save the image.
            rm -f ${FN}.tar
            time docker save -o ${FN}.tar ${IMG}
            if (( $? )) ; then
                echo -e "${RB}ERROR${RN}:${LINENO}: image not found: '$IMG'.${R}"
                exit 1
            fi
        done
    fi
fi

# Quit docker.
if dockerRunning ; then
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
    echo -e "${RB}ERROR${RN}:${LINENO}: Could not create the docker image file.${R}"
    exit 1
fi

# Restart docker.
dockerStart

# Restore the images.
if (( ${#IMAGES[@]} > 0 )) ; then
    # Re-populate the images.
    echo "INFO:${LINENO}: Restore the docker images."
    n=${#IMAGES[@]}
    i=0
    for IMG in ${IMAGES[@]} ; do
        (( i++ ))
        FN=$(echo -n "$IMG" | base64)
        echo "INFO:${LINENO}:    Restoring image $i of $n: '$FN.tar' --> '$IMG'."
        time docker load -q -i ${FN}.tar
        if (( $? )) ; then
            echo -e "${RB}WARNING${RN}:${LINENO}: Docker image not restored: '$FN.tar'.${R}"
        fi
    done

    # Do not delete the images if the user specified -k.
    if (( ! KEEP )) ; then
        echo "INFO:${LINENO}: Cleaning up."
        for IMG in ${IMAGES[@]} ; do
            FN=$(echo -n "$IMG" | base64)
            rm -f $FN.tar
        done
    fi
fi

# Now report the summary information.
echo -e "INFO:${LINENO}: ${GB}Docker images.${R}"
docker images

echo -e "INFO:${LINENO}: ${GB}Docker image repo info.${R}"
qemu-img info $DOCKER_IMG_FILE

echo -e "INFO:${LINENO}: ${GB}Docker image repo size.${R}"
ls -lh $DOCKER_IMG_FILE

echo -e "INFO:${LINENO}: ${GN}Done.${R}"
