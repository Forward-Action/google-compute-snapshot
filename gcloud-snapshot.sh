#!/usr/bin/env bash
#
# Take snapshots of Google Compute Engine disks

export PATH=$PATH:/usr/local/bin/:/usr/bin


###############################
##                           ##
## INITIATE SCRIPT FUNCTIONS ##
##                           ##
##  FUNCTIONS ARE EXECUTED   ##
##   AT BOTTOM OF SCRIPT     ##
##                           ##
###############################


#
# DOCUMENT ARGUMENTS
#

usage() {
    echo -e "\nUsage: $0 [-d <days>] [-r <remote_instances>] [-f <gcloud_filter_expression>] [-p <prefix>] [-a <service_account>] [-n <dry_run>]" 1>&2
    echo -e "\nOptions:\n"
    echo -e "    -d    Number of days to keep snapshots.  Snapshots older than this number deleted."
    echo -e "          Default if not set: 7 [OPTIONAL]"
    echo -e "    -r    Backup remote instances - takes snapshots of all disks calling instance has"
    echo -e "          access to [OPTIONAL]."
    echo -e "    -f    gcloud filter expression to query disk selection [OPTIONAL]"
    echo -e "    -p    Prefix to be used for naming snapshots."
    echo -e "          Max character length: 20"
    echo -e "          Default if not set: 'gcs' [OPTIONAL]"
    echo -e "    -a    Service Account to use."
    echo -e "          Blank if not set [OPTIONAL]"
    echo -e "    -n    Dry run: causes script to print debug variables and doesn't execute any"
    echo -e "          create / delete commands [OPTIONAL]"
    echo -e "\n"
    exit 1
}


#
# GET SCRIPT OPTIONS AND SETS GLOBAL VAR
#

setScriptOptions()
{
    while getopts ":d:rf:p:a:n" opt; do
        case $opt in
            d)
                opt_d=${OPTARG}
                ;;
            r)
                opt_r=true
                ;;
            f)
                opt_f=${OPTARG}
                ;;
            p)
                opt_p=${OPTARG}
                ;;
            a)
                opt_a=${OPTARG}
                ;;
            n)
                opt_n=true
                ;;
            *)
                usage
                ;;
        esac
    done
    shift $((OPTIND-1))

    # Number of days to keep snapshots
    if [[ -n $opt_d ]]; then
        OLDER_THAN=$opt_d
    else
        OLDER_THAN=7
    fi

    # Backup remote Instances
    if [[ -n $opt_r ]]; then
        REMOTE_CLAUSE=$opt_r
    fi

    # gcloud Filter
    if [[ -n $opt_f ]]; then
        FILTER_CLAUSE=$opt_f
    else
        FILTER_CLAUSE=""
    fi

    # Snapshot Prefix
    if [[ -n $opt_p ]]; then
        # check if prefix is more than 20 chars
        if [ ${#opt_p} -ge 20 ]; then
            PREFIX=${opt_p:0:20}
        else
            PREFIX=$opt_p
        fi
    else
        PREFIX="gcs"
    fi

    # gcloud Service Account
    if [[ -n $opt_a ]]; then
        OPT_ACCOUNT="--account $opt_a"
    else
        OPT_ACCOUNT=""
    fi

    # Dry run
    if [[ -n $opt_n ]]; then
        DRY_RUN=$opt_n
    fi

    # Debug - print variables
    if [ "$DRY_RUN" = true ]; then
        printDebug "OLDER_THAN=${OLDER_THAN}"
        printDebug "REMOTE_CLAUSE=${REMOTE_CLAUSE}"
        printDebug "FILTER_CLAUSE=${FILTER_CLAUSE}"
        printDebug "PREFIX=${PREFIX}"
        printDebug "OPT_ACCOUNT=${OPT_ACCOUNT}"
        printDebug "DRY_RUN=${DRY_RUN}"
    fi
}


#
# RETURN INSTANCE NAME
#

getInstanceName()
{
    if [ "$REMOTE_CLAUSE" = true ]; then
        # return blank so that it gets disks for all instances
        echo -e ""
    else
        # get the name for this vm
        local instance_name="$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/hostname" -H "Metadata-Flavor: Google")"

        # strip out the instance name from the fullly qualified domain name the google returns
        echo -e "${instance_name%%.*}"
    fi
}


#
# RETURNS LIST OF DEVICES
#
# input: ${INSTANCE_NAME}
#

getDeviceList()
{
    echo -e "$(gcloud $OPT_ACCOUNT compute disks list $1 --filter "$FILTER_CLAUSE" --format='value(name,zone,id)')"
}


#
# RETURNS SNAPSHOT NAME
#
# input: ${PREFIX} ${DEVICE_NAME} ${DATE_TIME}
#

createSnapshotName()
{
    # create snapshot name
    local name="$1-$2-$3"

    # google compute snapshot name cannot be longer than 62 characters
    local name_max_len=62

    # check if snapshot name is longer than max length
    if [ ${#name} -ge ${name_max_len} ]; then

        # work out how many characters we require - prefix + timestamp
        local req_chars="$1--$3"

        # work out how many characters that leaves us for the device name
        local device_name_len=`expr ${name_max_len} - ${#req_chars}`

        # shorten the device name
        local device_name=${2:0:device_name_len}

        # create new (acceptable) snapshot name
        name="$1-${device_name}-$3" ;

    fi

    echo -e ${name}
}


#
# CREATES SNAPSHOT AND RETURNS OUTPUT
#
# input: ${DEVICE_NAME}, ${SNAPSHOT_NAME}, ${DEVICE_ZONE}
#

createSnapshot()
{
    if [ "$DRY_RUN" = true ]; then
        printCmd "gcloud ${OPT_ACCOUNT} compute disks snapshot $1 --snapshot-names $2 --zone $3"
    else
        $(gcloud $OPT_ACCOUNT compute disks snapshot $1 --snapshot-names $2 --zone $3)
    fi
}


#
# RETURNS DELETION DATE FOR ALL SNAPSHOTS
#
# input: ${OLDER_THAN}
#

getSnapshotDeletionDate()
{
    echo -e "$(date -d "-$1 days" +"%Y%m%d")"
}


#
# DELETE SNAPSHOTS FOR DISK
#
# input: ${SNAPSHOT_PREFIX} ${DELETION_DATE} ${DEVICE_ID}
#

deleteSnapshots()
{
    # create empty array
    local snapshots=()

    # get list of snapshots from gcloud for this device
    local gcloud_response="$(gcloud $OPT_ACCOUNT compute snapshots list --filter="name~'"$1"' AND creationTimestamp<'$2' AND sourceDiskId='$3'" --uri)"

    # loop through and get snapshot name from URI
    while read line
    do
        # grab snapshot name from full URI
        snapshot="${line##*/}"

        # add snapshot to global array
        snapshots+=(${snapshot})

    done <<< "$(echo -e "$gcloud_response")"

    # loop through array
    for snapshot in "${snapshots[@]}"; do
        # delete snapshot
        deleteSnapshot ${snapshot}
    done
}


#
# DELETES SNAPSHOT
#
# input: ${SNAPSHOT_NAME}
#

deleteSnapshot()
{
    if [ "$DRY_RUN" = true ]; then
        printCmd "gcloud ${OPT_ACCOUNT} compute snapshots delete $1 -q"
    else
        $(gcloud $OPT_ACCOUNT compute snapshots delete $1 -q)
    fi
}


logTime()
{
    local datetime="$(date +"%Y-%m-%d %T")"
    echo -e "[$datetime]: $1"
}

printDebug()
{
    echo -e "$(tput setab 4)[DEBUG]:$(tput sgr 0) $(tput setaf 4)${1}$(tput sgr 0)"
}

printError()
{
    echo -e "$(tput setab 1)[ERROR]:$(tput sgr 0) $(tput setaf 1)${1}$(tput sgr 0)"
}

printCmd()
{
    echo -e "$(tput setab 3)$(tput setaf 0)[CMD]:$(tput sgr 0) $(tput setaf 3)${1}$(tput sgr 0)"
}


######################
##                  ##
## WRAPPER FUNCTION ##
##                  ##
######################


main()
{
    # log time
    logTime "Start of google-compute-snapshot"

    # set script options
    setScriptOptions "$@"

    # get current datetime
    DATE_TIME="$(date "+%s")"

    # get deletion date for existing snapshots
    DELETION_DATE=$(getSnapshotDeletionDate "${OLDER_THAN}")

    # get local instance name (blank if using remote instances)
    INSTANCE_NAME=$(getInstanceName)

    # dry run: debug output
    if [ "$DRY_RUN" = true ]; then
        printDebug "DATE_TIME=${DATE_TIME}"
        printDebug "DELETION_DATE=${DELETION_DATE}"
        printDebug "INSTANCE_NAME=${INSTANCE_NAME}"
    fi

    # get list of all the disks that match filter
    DEVICE_LIST=$(getDeviceList ${INSTANCE_NAME})

    # check if any disks were found
    if [[ -z $DEVICE_LIST ]]; then
        printError "No disks were found - please check your script options / account permissions."
        exit 1
    fi

    # dry run: debug disk output
    if [ "$DRY_RUN" = true ]; then
        printDebug "DEVICE_LIST=${DEVICE_LIST}"
    fi

    # loop through the devices
    echo "${DEVICE_LIST}" | while read device_name device_zone device_id; do
        logTime "Handling Snapshots for ${device_name}"

        # build snapshot name
        local snapshot_name=$(createSnapshotName ${PREFIX} ${device_name} ${DATE_TIME})

        # create the snapshot
        createSnapshot ${device_name} ${snapshot_name} ${device_zone}

        # delete snapshots for this disk that were created older than DELETION_DATE
        deleteSnapshots "$PREFIX-.*" "$DELETION_DATE" "${device_id}"
    done

    logTime "End of google-compute-snapshot"
}


####################
##                ##
## EXECUTE SCRIPT ##
##                ##
####################

main "$@"