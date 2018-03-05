#!/bin/bash

set -e

log() {
    echo "[$(date +"%Y-%m-%d+%T")]: $*"
}

usage() {
cat << EOF
Usage: ${0##*/} ...
    -c <Snapshot Type>   Create snapshot with type <Snapshot Type>
    -d <Existing Snapshot ID> Delete given Snapshot
    -l  List Snapshots of type Scheduled for volume
    -p  Purge old snapshots for volume
    -h  Display an help message

Environment Variables
---------------------
CUSTOM_INSTANCE_ID  If you want to force the script to use a specific EC2 instance instead of letting it figure it out.
CUSTOM_DATA_DEVICE Is used to alter the default data device used by this script. ["/dev/sdf"]
CUSTOM_RETENTION_PERIOD  Is used to configure the period Snapshot should be kept. Need to be a valid date input. ["7 days"]  *

* This will affect only the Snapshot of type "Scheduled"
EOF
}


get_instance_id() {
  local instance_id=
  instance_id=$(wget -q -O- "${AWS_METADATA_URL}/instance-id")
  echo "${instance_id}"
}

get_tags_for_instance() {
  local instance_id=${1:?"Instance ID is required"}
  aws ec2 describe-tags \
    --filters "[ { \"Name\": \"resource-id\", \"Values\": [\"${instance_id}\"]} ]" \
    --query 'Tags[].{key:Key, value:Value}' --output text

}

get_data_volume_id_for_instance() {
  local instance_id=${1:?"Instance ID is required"}
  local volume_id=
  volume_id=$(aws ec2 describe-volumes --filters "[
    { \"Name\": \"attachment.instance-id\", \"Values\": [\"${instance_id}\"] },
    { \"Name\": \"attachment.device\", \"Values\": [\"${snapshot_device}\"] } 
  ]" --query "Volumes[0].VolumeId" --output text)
  echo "${volume_id}"
}

get_snapshots_for_given_volume_and_type() {
  local volume_id=${1:?"Volume ID is required"}
  local snapshot_type=${2:?"Snapshot Type is required"}
  aws ec2 describe-snapshots \
    --filters "[
                { \"Name\": \"volume-id\", \"Values\": [\"${volume_id}\"] },
                { \"Name\": \"tag:SnapshotType\", \"Values\": [\"${snapshot_type}\"] }
               ]" \
    --query 'Snapshots[].{Time:StartTime, ID:SnapshotId}' \
    --output text
}

create_snapshot_for_given_volume() {
  local volume_id=${1:?"Volume ID is required"}
  local snapshot_type=${2:?"SnapshotType must be provided"}
  local snapshot_timestamp=
  snapshot_timestamp=$(date +%s)
  local snapshot_date=
  snapshot_date=$(date -d @"${snapshot_timestamp}" +"%Y-%m-%d_%T")
  local instance_id=$INSTANCE_ID
  
  declare -A instance_tags

  while read -r LINE; do
    instance_tags[${LINE%%[[:space:]]*}]=${LINE##*[[:space:]]}
  done <<< "$(get_tags_for_instance "${instance_id}" )"
  
  aws ec2 create-snapshot --volume-id "${volume_id}" \
    --description "${snapshot_type} Snapshot for ${volume_id} on ${instance_id} generated on ${snapshot_date}" \
    --tag-specifications "[ 
      { \"ResourceType\": \"snapshot\",
        \"Tags\": [ 
          { \"Key\": \"Name\", \"Value\": \"${instance_tags["Name"]}-data-snap-${snapshot_timestamp}\" },
          { \"Key\": \"CreatedBy\", \"Value\": \"AutomatedBackup\" },
          { \"Key\": \"CreatedFromInstance\", \"Value\": \"${instance_id}\" },
          { \"Key\": \"SnapshotType\", \"Value\": \"${snapshot_type}\" },
          { \"Key\": \"Environment\", \"Value\": \"${instance_tags["Environment"]}\" }
        ]
      }]" --output table
}

delete_given_snapshot() {
  local snapshot_id=${1:?"Snapshot ID is required"}
  log "Deleting Snapshot [${snapshot_id}]"
  aws ec2 delete-snapshot --snapshot-id "${snapshot_id}"
}

cleanup_snapshots() {
  local volume_id=${1:?"Volume ID is required"}
  declare -A snapshot_time_map

  while read -r LINE; do
    if [[ -n $LINE ]]; then
      snapshot_time_map[${LINE%%[[:space:]]*}]=${LINE##*[[:space:]]}
    else
      log "No Snapshots for given volume [${volume_id}] match criteria"
    fi
  done <<< "$(get_snapshots_for_given_volume_and_type "$volume_id" "Scheduled")"

  local snapshot_date=
  local snapshot_date_in_seconds=
  for snap in "${!snapshot_time_map[@]}"; do
    snapshot_date="${snapshot_time_map["${snap}"]}"
    snapshot_date_in_seconds=$(date -d "${snapshot_date}" +%s)

    # shellcheck disable=SC2004
    if (( $snapshot_date_in_seconds <= $retention_date_in_seconds )); then
      delete_given_snapshot "${snap}"
    else
      log "Snapshot [${snap}] is not older than ${retention_period} days, so we keep it."
    fi
  done
}

[ $# -eq 0 ] && { usage ; exit 1; }

AWS_METADATA_URL="http://169.254.169.254/latest/meta-data"


retention_period="${CUSTOM_RETENTION_PERIOD:-"7 days"}"
retention_date_in_seconds=$(date +%s --date "${retention_period} ago")
snapshot_device="${CUSTOM_DATA_DEVICE:-"/dev/sdf"}"
if [[ -z $CUSTOM_INSTANCE_ID ]]; then
  INSTANCE_ID=$(get_instance_id)
else
  INSTANCE_ID=$CUSTOM_INSTANCE_ID
fi
VOLUME_ID=$(get_data_volume_id_for_instance "${INSTANCE_ID}")
log "================================"
log "EBS Data Volume Snapshot Creator"
log "================================"
log
log "Working on Instance [${INSTANCE_ID}] with volume [${VOLUME_ID}] of device [${snapshot_device}]"
while getopts ":c:d:pl" OPTION ; do
  case "$OPTION" in
    c )
      log
      log "Create snapshot with type ${OPTARG}"
      create_snapshot_for_given_volume "${VOLUME_ID}" "${OPTARG}"
      log
      ;;
    d )
      log
      log "Deleting Snapshot ${OPTARG}"
      delete_given_snapshot "${OPTARG}"
      log
      ;;
    l )
      log
      log "Listing Snapshots of type Scheduled for volume [${VOLUME_ID}]..."
      get_snapshots_for_given_volume_and_type "$VOLUME_ID" "Scheduled"
      log "Done"
      log
      ;;
    p )
      log
      log "Purging old snapshots for volume [${VOLUME_ID}]"
      cleanup_snapshots "$VOLUME_ID"
      log
      ;;
    \? )
      log "Display an help message"
      usage
      ;;
    * )
      log "An Error occured! Try reviewing your arguments."
      usage
      exit 255
      ;;
  esac
done
