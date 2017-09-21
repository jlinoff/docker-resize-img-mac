#!/bin/bash
#
# Backup images.
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
    Backup your docker images so that they are not lost if a catastrophic
    failure occurs.

    The backup is created in ${B}${BACKUP_DIR}${R}.

    It saves the images and creates a ${B}restore.sh${R} script
    that will automatically restore the images.

    By default all images except ${B}none${R} are saved. You can
    specify specific images if you want.

OPTIONS
    -h, --help      This help message.

    -V, --version   Print the program version and exit.

EXAMPLE USAGE
    # Example 1: Help
    \$ ${B}$bn -h${R}

    # Example 2: Version
    \$ ${B}$bn -V${R}

    # Example 3: Backup all of the images.
    \$ ${B}$bn${R}

    # Example 4: Backup some specific images.
    \$ ${B}$bn centos ubuntu alpine:latest${R}

    # Example 5: Restore the images.
    \$ ${B}cd \$(ls -1d backup/* | head -1)${R}
    \$ ${B}./restore.sh${R}

LICENSE
    Copyright (c) 2017 by Joe Linoff
    MIT Open Source

VERSION
    $VERSION
"
    exit 0
}

# ================================================================
# Main
# ================================================================
# Grab command line arguments.
readonly VERSION='0.6.0'
readonly B=$(printf "\x1B[1m")
readonly R=$(printf "\x1B[0m")
readonly RB=$(printf "\x1B[1;31m")  # red-bold
readonly RN=$(printf "\x1B[0;31m")  # red-normal
readonly GB=$(printf "\x1B[1;32m")  # green-bold
readonly GN=$(printf "\x1B[0;32m")  # green-normal
readonly DATETIME_STAMP="$(date +%Y%m%d-%T%z | tr -d ':')"
readonly BACKUP_DIR="backup/${DATETIME_STAMP}"

IMAGES=()

while (( $# )) ; do
    arg=$1
    shift
    case "$arg" in
        -h|--help)
            helpme
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

n=${#IMAGES[@]}
if (( n == 0 )) ; then
    IMAGES=($(docker images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>'))
    n=${#IMAGES[@]}
fi

echo "INFO:${LINENO}: $n images specified."
if (( n > 0 )) ; then
    echo "INFO:${LINENO}: Creating $BACKUP_DIR."
    mkdir -p $BACKUP_DIR
    cd $BACKUP_DIR
    docker images >images.txt

    cat >restore.sh <<EOF
#!/bin/bash
# Automatically created by $0 to
# restore backed up images.
set -e
EOF
    chmod 0755 restore.sh

    # Backup the specified images.
    i=0
    for IMG in ${IMAGES[@]} ; do
        echo "INFO:${LINENO}: Backing up ${IMG}."
        MATCHES=($(docker images --format '{{.Repository}}:{{.Tag}}' | grep "${IMG}"))
        m=${#MATCHES[@]}
        echo "INFO:${LINENO}:   Found $m matches."
        for MATCH in ${MATCHES[@]} ; do
            echo "INFO:${LINENO}:   Backing up image: ${B}$MATCH${R}."
            (( i++ ))
            REC=$(docker images --format '{{.Repository}}:{{.Tag}},{{.ID}},{{.Size}}' | \
                     grep "${MATCH},")
            ID=$(echo "$REC" | awk -F, '{print $2}')
            echo "INFO:${LINENO}:     ID=${ID}"
            IMG_SIZE=$(echo "$REC" | awk -F, '{print $3}')
            echo "INFO:${LINENO}:     SIZE=${IMG_SIZE}"
            TAR_FILE=$(printf "img%03d-%s.tar" "$i" "$ID")
            echo "INFO:${LINENO}:     TAR_FILE=${TAR_FILE}"
            cat >>restore.sh <<EOF

# Restoring $MATCH.
echo "INFO:\${LINENO}: Restoring $MATCH."
docker load -i ${TAR_FILE}
EOF
            SAVE="time docker save ${MATCH} -o ${TAR_FILE}"
            echo -e "INFO:${LINENO}:     ${GB}$SAVE${R}"
            eval "$SAVE"
            if (( $? )) ; then
                echo -e "${RB}ERROR${RN}:${LINENO}: Command failed.{R}"
                qemu-img info $DOCKER_IMG_REPO
                exit 1
            fi
        done
    done
fi

echo -e "INFO:${LINENO}: ${GN}Done.${R}"
