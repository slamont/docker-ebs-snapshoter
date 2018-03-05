slamontagne/ebs-snapshoter
======================

Docker container that periodically launch the creation of snapshot for given Amazon EBS ressources using [awscli](https://aws.amazon.com/cli/) and cron.

### Usage

    docker run -d [options] slamontagne/ebs-snapshoter 

#### Options

| Name                                                | Operation         | Required | Description |
| -------------------------------------------------   | ----------------- | -------- | --------------------------- |
| -e ACCESS_KEY='AWS_KEY'                             | all               | yes      |  Your AWS key               |
| -e SECRET_KEY='AWS_SECRET'                          | all               | yes      | Your AWS secret             |
| -e CUSTOM_INSTANCE_ID='i-1234567890abcd'            | all               | no       | Used to override the script instance auto-detection |
| -e CUSTOM_DATA_DEVICE='/dev/sdf'                    | all               | no       | Used to override the default device name |
| -e CUSTOM_RETENTION_PERIOD='30 days'                | all               | no       | Used to override the script default retention period |
| -e CRON_SCHEDULE='5 3 \* \* \*'                     | schedule          | no       | Specifies when cron job runs, see [format](http://en.wikipedia.org/wiki/Cron). Default is 5 3 \* \* \*, runs every night at 03:05 |


### Examples:

Schedule Snapshot everyday at 12:00:

    docker run -d \
      -e ACCESS_KEY=myawskey \
      -e SECRET_KEY=myawssecret \
      -e CRON_SCHEDULE='0 12 * * *' \
      slamontagne/ebs-snapshoter schedule

Snapshot once and then delete the container:

    docker run --rm \
      -e ACCESS_KEY=myawskey \
      -e SECRET_KEY=myawssecret \
      slamontagne/ebs-snapshoter snapshot-once



### Disclaimer

This project is based from the idea implemented in https://github.com/strawpay/docker-backup-to-s3
Some part were inspired by https://github.com/bkrodgers/aws-ec2-ebs-automatic-snapshot-bash


### Concept

The idea is to wrap the aws cli command to:

* Create new Snapshot for a given Volume
* Scheduled the creation of snapshots
* Manage the amount of Snapshots to keep for a given Volume (Should it be able to Pin a snapshot)
* Delete Snapshots
