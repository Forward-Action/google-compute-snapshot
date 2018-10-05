#!/usr/bin/env bash
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
# DOCUMENTS ARGUMENTS
#

usage() {
    echo -e "\nUsage: $0 [-d <days>] [-t <label_name>] [-i <instance_name>] [-z <instance_zone>] [-p <prefix>]" 1>&2
    echo -e "\nOptions:\n"
    echo -e "    -d    Number of days to keep snapshots.  Snapshots older than this number deleted."
    echo -e "          Default if not set: 7 [OPTIONAL]"
    echo -e "    -t    Only back up disks that have this specified label with value set to 'true'."
    echo -e "    -i    Instance name to create backups for. If empty, makes backup for the calling"
    echo -e "          host."
    echo -e "    -z    Instance zone. If empty, uses the zone of the calling host."
    echo -e "    -p    Prefix to be used for naming snapshots, default to 'gcs'"
    echo -e "    -a    Service Account to use. If empty, it uses the gcloud default."
    echo -e "\n"
    exit 1
}


#
# GETS SCRIPT OPTIONS AND SETS GLOBAL VAR $OLDER_THAN
#

setScriptOptions()
{
    while getopts ":d:t:i:z:p:" o; do
        case "${o}" in
            d)
                opt_d=${OPTARG}
                ;;
            t)
                opt_t=${OPTARG}
                ;;
            i)
                opt_i=${OPTARG}
                ;;
            z)
                opt_z=${OPTARG}
                ;;
            p)
                opt_p=${OPTARG}
                ;;
            a)  opt_a=${OPTARG}
                ;;
            *)
                usage
                ;;
        esac
    done
    shift $((OPTIND-1))

    if [[ -n $opt_d ]];then
        OLDER_THAN=$opt_d
    else
        OLDER_THAN=7
    fi

    if [[ -n $opt_t ]];then
        LABEL_CLAUSE="AND labels.$opt_t=true"
    else
        LABEL_CLAUSE=""
    fi

    if [[ -n $opt_i ]];then
        OPT_INSTANCE_NAME=$opt_i
    else
        OPT_INSTANCE_NAME=""
    fi

    if [[ -n $opt_z ]];then
        OPT_INSTANCE_ZONE=$opt_z
    else
        OPT_INSTANCE_ZONE=""
    fi

    if [[ -n $opt_p ]];then
        PREFIX=$opt_p
    else
        PREFIX="gcs"
    fi

    if [[ -n $opt_a ]];then
        OPT_INSTANCE_SERVICE_ACCOUNT="--account $opt_a"
    else
        OPT_INSTANCE_SERVICE_ACCOUNT=""
    fi
}


#
# RETURNS INSTANCE NAME
#

getInstanceName()
{
    if [[ -z "$OPT_INSTANCE_NAME" ]];then
        # get the name for this vm
        local instance_name="$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/hostname" -H "Metadata-Flavor: Google")"

        # strip out the instance name from the fullly qualified domain name the google returns
        echo -e "${instance_name%%.*}"
    else
        echo $OPT_INSTANCE_NAME
    fi
}


#
# RETURNS INSTANCE ID
#

getInstanceId()
{
    if [[ -z "$OPT_INSTANCE_NAME" ]];then    # no typo: only when querying for the calling machine get the real instance ID
        echo -e "$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/id" -H "Metadata-Flavor: Google")"
    else
        echo -e "$(gcloud $OPT_INSTANCE_SERVICE_ACCOUNT -q compute instances describe $OPT_INSTANCE_NAME --zone=$INSTANCE_ZONE --format='value(id)')"
    fi
}


#
# RETURNS INSTANCE ZONE
#

getInstanceZone()
{
    if [[ -z "$OPT_INSTANCE_ZONE" ]];then
        local instance_zone="$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google")"

        # strip instance zone out of response
        echo -e "${instance_zone##*/}"
    else
        echo $OPT_INSTANCE_ZONE
    fi
}


#
# RETURNS LIST OF DEVICES
#
# input: ${INSTANCE_NAME}
#

getDeviceList()
{
    echo -e "$(gcloud $OPT_INSTANCE_SERVICE_ACCOUNT compute disks list --filter "users~instances/$1\$ $LABEL_CLAUSE" --format='value(name)')"
}


#
# RETURNS SNAPSHOT NAME
#

createSnapshotName()
{
    # create snapshot name
    local name="$PREFIX-$1-$2-$3"

    # google compute snapshot name cannot be longer than 62 characters
    local name_max_len=62

    # check if snapshot name is longer than max length
    if [ ${#name} -ge ${name_max_len} ]; then

        # work out how many characters we require - prefix + device id + timestamp
        local req_chars="$PREFIX--$2-$3"

        # work out how many characters that leaves us for the device name
        local device_name_len=`expr ${name_max_len} - ${#req_chars}`

        # shorten the device name
        local device_name=${1:0:device_name_len}

        # create new (acceptable) snapshot name
        name="$PREFIX-${device_name}-$2-$3" ;

    fi

    echo -e ${name}
}


#
# CREATES SNAPSHOT AND RETURNS OUTPUT
#
# input: ${DEVICE_NAME}, ${SNAPSHOT_NAME}, ${INSTANCE_ZONE}
#

createSnapshot()
{
    echo -e "$(gcloud $OPT_INSTANCE_SERVICE_ACCOUNT compute disks snapshot $1 --snapshot-names $2 --zone $3)"
}


#
# GETS LIST OF SNAPSHOTS AND SETS GLOBAL ARRAY $SNAPSHOTS
#
# input: ${SNAPSHOT_REGEX}
# example usage: getSnapshots "(gcs-.*${INSTANCE_ID}-.*)"
#

getSnapshotsForDeletion()
{
    # create empty array
    SNAPSHOTS=()

    # get list of snapshots from gcloud for this device
    local gcloud_response="$(gcloud $OPT_INSTANCE_SERVICE_ACCOUNT compute snapshots list --filter="name~'"$1"' AND creationTimestamp<'$2'" --uri)"

    # loop through and get snapshot name from URI
    while read line
    do
        # grab snapshot name from full URI
        snapshot="${line##*/}"

        # add snapshot to global array
        SNAPSHOTS+=(${snapshot})

    done <<< "$(echo -e "$gcloud_response")"
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
# DELETES SNAPSHOT
#
# input: ${SNAPSHOT_NAME}
#

deleteSnapshot()
{
    echo -e "$(gcloud $OPT_INSTANCE_SERVICE_ACCOUNT compute snapshots delete $1 -q)"
}


logTime()
{
    local datetime="$(date +"%Y-%m-%d %T")"
    echo -e "$datetime: $1"
}


#######################
##                   ##
## WRAPPER FUNCTIONS ##
##                   ##
#######################


createSnapshotWrapper()
{
    # log time
    logTime "Start of createSnapshotWrapper"

    # get date time
    DATE_TIME="$(date "+%s")"

    # get the instance name
    INSTANCE_NAME=$(getInstanceName)

    # get the instance zone
    INSTANCE_ZONE=$(getInstanceZone)

    # get the device id
    INSTANCE_ID=$(getInstanceId)

    # get a list of all the devices
    DEVICE_LIST=$(getDeviceList ${INSTANCE_NAME})

    # create the snapshots
    echo "${DEVICE_LIST}" | while read DEVICE_NAME
    do
        # create snapshot name
        SNAPSHOT_NAME=$(createSnapshotName ${DEVICE_NAME} ${INSTANCE_ID} ${DATE_TIME})

        # create the snapshot
        OUTPUT_SNAPSHOT_CREATION=$(createSnapshot ${DEVICE_NAME} ${SNAPSHOT_NAME} ${INSTANCE_ZONE})
    done
}

deleteSnapshotsWrapper()
{
    # log time
    logTime "Start of deleteSnapshotsWrapper"

    # get the deletion date for snapshots
    DELETION_DATE=$(getSnapshotDeletionDate "${OLDER_THAN}")

    # get list of snapshots for regex and that were created older that DELETION_DATE - saved in global array
    getSnapshotsForDeletion "$PREFIX-.*${INSTANCE_ID}-.*" "$DELETION_DATE"

    # loop through snapshots
    for snapshot in "${SNAPSHOTS[@]}"
    do
        # delete snapshot
        OUTPUT_SNAPSHOT_DELETION=$(deleteSnapshot ${snapshot})
    done
}




##########################
##                      ##
## RUN SCRIPT FUNCTIONS ##
##                      ##
##########################

# log time
logTime "Start of Script"

# set options from script input / default value
setScriptOptions "$@"

# create snapshot
createSnapshotWrapper

# delete snapshots older than 'x' days
deleteSnapshotsWrapper

# log time
logTime "End of Script"
