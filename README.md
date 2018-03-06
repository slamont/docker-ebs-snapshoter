slamont/ebs-snapshoter
======================

Docker container that periodically launch the creation of snapshot for given Amazon EBS ressources using [awscli](https://aws.amazon.com/cli/) and cron.

### Usage

    docker run -d [options] slamont/ebs-snapshoter [schedule|snapshot-once]



#### Options

| Name                                                | Operation         | Required | Description |
| -------------------------------------------------   | ----------------- | -------- | --------------------------- |
| -e ACCESS_KEY='AWS_KEY'                             | all               | yes      |  Your AWS key               |
| -e SECRET_KEY='AWS_SECRET'                          | all               | yes      | Your AWS secret             |
| -e AWS_REGION='us-east-1'                           | all               | no       | Your AWS region. If not specified it will use 'us-east-1' as default |
| -e CUSTOM_INSTANCE_ID='i-1234567890abcdefg'         | all               | no       | Used to override the script instance auto-detection |
| -e CUSTOM_DATA_DEVICE='/dev/sdf'                    | all               | no       | Used to override the default device name. ** Be aware that it use the device name from the AWS API. It may be different under Linux.** In a Ubuntu 16.04, the volume with an AWS device name of '/dev/sdf' was detected as '/dev/xvdf', but we still need to use '/dev/sdf' for the script.  See [AWS Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html) to better understand. |
| -e CUSTOM_RETENTION_PERIOD='7 days'                 | all               | no       | Used to override the script default retention period |
| -e CRON_SCHEDULE='5 3 \* \* \*'                     | schedule          | no       | Specifies when cron job runs, see [format](http://en.wikipedia.org/wiki/Cron). Default is ```5 3 * * *```, runs every night at 03:05 |

#### Usage for snapshot.sh

The entrypoint of the container will delegate execution if you provide something else than ```schedule``` or ```snapshot-once```. For example, you can call the snapshot.sh script directly by doing this:

    docker run -d [options] slamont/ebs-snapshoter /snapshot.sh [script options]


##### Options for snapshot.sh

| Options                      | Description |
| ---------------------------  | ----------- |
| -c <Snapshot Type>           | Create snapshot with type <Snapshot Type> |
| -d <Existing Snapshot ID>    | Delete given Snapshot |
| -l                           | List Snapshots of type Scheduled for volume |
| -p                           | Purge old snapshots of type 'Scheduled' for volume |
| -h                           | Display an help message |

##### Environment Variables for snapshot.sh

| Name                    | Description |
| ----------------------- | ----------- |
| CUSTOM_INSTANCE_ID      | If you want to force the script to use a specific EC2 instance instead of letting it figure it out. |
| CUSTOM_DATA_DEVICE      | Is used to alter the default data device used by this script. ["/dev/sdf"] |
| CUSTOM_RETENTION_PERIOD | Is used to configure the period Snapshot should be kept. Need to be a valid date input. ["7 days"] |


### Examples:

Schedule Snapshot everyday at 12:00:
```
docker run -d \
  -e ACCESS_KEY='myawskey' \
  -e SECRET_KEY='myawssecret' \
  -e CRON_SCHEDULE='0 12 * * *' \
  slamont/ebs-snapshoter schedule
```

Snapshot once and then delete the container:
```
docker run --rm \
  -e ACCESS_KEY='myawskey' \
  -e SECRET_KEY='myawssecret' \
  slamont/ebs-snapshoter snapshot-once
```

List all existing 'Scheduled' snapshot for data volume of the given instance:
```
docker run -it --rm \
  -e ACCESS_KEY='myawskey' \
  -e SECRET_KEY='myawssecret' \
  -e CUSTOM_INSTANCE_ID='i-1234567890abcdefg' \
  slamont/ebs-snapshoter /snapshot.sh -l
```

### Docker Compose

Simple example to use it with Docker Compose

```
  #Snapshot Container
  ebs_snapshoter:
    container_name: ebs-snapshoter
    image: slamont/ebs-snapshoter:latest
    command: 'schedule'
    restart: always
    environment:
      ACCESS_KEY: 'myawskey'
      SECRET_KEY: 'myawssecret'
      CRON_SCHEDULE: '0 12 * * *'
    logging:
      driver: journald
```


### Disclaimer

This project is based from the idea implemented in https://github.com/strawpay/docker-backup-to-s3
Some part were inspired by https://github.com/bkrodgers/aws-ec2-ebs-automatic-snapshot-bash


### Concept

The idea is to wrap the ```aws``` cli command to:

* Create new Snapshot for a given Volume
* Scheduled the creation of snapshots
* Manage the amount of Snapshots to keep for a given Volume (Should it be able to Pin a snapshot)
* Delete Snapshots
