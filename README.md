# Automatic Snapshots for Google (gcloud) Compute Engine

Bash script for Automatic Snapshots and Cleanup on Google Compute Engine. 

**Requires no user input!**

_Inspiration (and the installation instructions) taken from AWS script [aws-ec2-ebs-automatic-snapshot-bash](https://github.com/CaseyLabs/aws-ec2-ebs-automatic-snapshot-bash)_

## How it works
gcloud-snapshot.sh will:

- Determine the Instance ID of the Google Compute Engine server on which the script runs
- Get all the Disk IDs attached to that instance
- Take a snapshot of each Disk
- The script will then delete all associated snapshots taken by the script for the Instance that are older than 7 days 

The script has a number of **optional** usage options - for example you can:

- Retain snapshots for as long as you'd like [(-d)](#snapshot-retention)
- Backup remote instances too [(-r)](#backing-up-remote-instances)
- Only backup certain disks [(-f)](#matching-on-specific-disks)

## Prerequisites
* `cURL` must be installed
* The VM must have the sufficient gcloud permissions, including "compute" set to "enabled": [	http://stackoverflow.com/questions/31905966/gcloud-compute-list-networks-error-some-requests-did-not-succeed-insufficie#31928399](http://stackoverflow.com/questions/31905966/gcloud-compute-list-networks-error-some-requests-did-not-succeed-insufficie#31928399)
* The version of gcloud is up to date: `gcloud components update` 


## Installation

ssh on to the server you wish to have backed up

**Install Script**: Download the latest version of the snapshot script and make it executable:
```
cd ~
wget https://raw.githubusercontent.com/jacksegal/google-compute-snapshot/master/gcloud-snapshot.sh
chmod +x gcloud-snapshot.sh
sudo mkdir -p /opt/google-compute-snapshot
sudo mv gcloud-snapshot.sh /opt/google-compute-snapshot/
sudo gcloud auth login
```

**To manually test the script:**
```
sudo /opt/google-compute-snapshot/gcloud-snapshot.sh
```

## Automation

**Setup CRON**: You should setup a cron job in order to schedule a daily backup. Example cron for Debian based Linux:
```
0 5 * * * sudo -u root /opt/google-compute-snapshot/gcloud-snapshot.sh > /dev/null 2>&1
```

If you'd like to save the output of the script to a log, see [Saving output to Log](#saving-output-to-log)

## Usage Options

```
Usage:

./gcloud-snapshot.sh [-d <days>] [-r <remote_instances>] [-f <gcloud_filter_expression>] [-p <prefix>] [-a <service_account>] [-n <dry_run>]

Options:

    -d    Number of days to keep snapshots.  Snapshots older than this number deleted.
          Default if not set: 7 [OPTIONAL]
    -r    Backup remote instances - takes snapshots of all disks calling instance has
          access to [OPTIONAL].
    -f    gcloud filter expression to query disk selection [OPTIONAL]
    -p    Prefix to be used for naming snapshots.
          Max character length: 20
          Default if not set: 'gcs' [OPTIONAL]
    -a    Service Account to use. 
          Blank if not set [OPTIONAL]
    -j    Project ID to use.
          Blank if not set [OPTIONAL]
    -n    Dry run: causes script to print debug variables and doesn't execute any 
          create / delete commands [OPTIONAL]
```

## Docker Support

This project has a `Dockerfile` and can therefore be run as a container in a VM, or in a Kubernetes cluster.
In this context, it will be run with the `-r` option to back up all disks the container has access to. The
intended usage is to run the container periodically as a Kubernetes cron task.

However it is also possible to set the environment variables `DAEMON` which will make the container run
continually and take snapshots at intervals. By default the interval is 21600 seconds (6 hours) but can
be overridden by setting the environment variable `SLEEP`.

You set environment variable `FILTER` to set a filter condition as documented in
[Matching on specific disks](#matching-on-specific-disks). Otherwise all disks are snapshotted.

At the time of writing, this image is available on [Docker Hub](https://hub.docker.com/r/jacksegal/google-compute-snapshot/)
as `jacksegal/google-compute-snapshot`.

## Usage Examples

### Snapshot Retention
By default snapshots will be kept for 7 days, however they can be kept for longer / shorter, by using the the -d flag:

    Usage: ./snapshot.sh [-d <days>]
    
    Options:
    
       -d  Number of days to keep snapshots. Snapshots older than this number deleted.
           Default if not set: 7 [OPTIONAL]

For example if you wanted to keep your snapshots for a year, you could run:

    ./gcloud-snapshot.sh -d 365

### Backing up Remote Instances
By default the script will only backup disks attached to the calling Instance, however you can backup all remote disks that the instance has access to, by using the -r flag:

    Usage: ./snapshot.sh [-r <remote_instances>]
    
    Options:
    
       -r  Backup remote instances - takes snapshots of all disks calling instance has
           access to [OPTIONAL].

For example:

    ./gcloud-snapshot.sh -r

### Matching on specific disks
By default snapshots will be created for all attached disks.  To only snapshot specific disks, pass in [gcloud filter expressions](https://cloud.google.com/sdk/gcloud/reference/topic/filters) using the -f flag:

    Usage: ./gcloud-snapshot.sh [-f <gcloud_filter_expression>]
    
    Options:
    
       -f  gcloud filter expression to query disk selection

Using Labels: You could add a label of `auto_snapshot=true` to all disks that you wanted backed up and then run:

    ./gcloud-compute-snapshot.sh -f "labels.auto_snapshot=true"

Backup specific zone: If you wanted to only backup disks in a specific zone you could run:

    ./gcloud-compute-snapshot.sh -f "zone: us-central1-c"

### Snapshot prefix
By default snapshots are created with a prefix of `gcs`. To give a custom prefix use the -p flag:

    Usage: ./gcloud-snapshot.sh [-p <prefix>]
    
    Options:
    
       -p  Prefix to be used for naming snapshots.
           Max character length: 20
           Default if not set: 'gcs' [OPTIONAL]

For example:

    ./gcloud-snapshot.sh -p "my-snap"

    (Note: Snapshot prefixes are limited to 20 characters)

### Service Account
By default snapshots are created with the default gcloud service account. To use a custom service account use the -a flag:

    Usage: ./gcloud-snapshot.sh [-a <service_account>]
    
    Options:
    
       -a  Service Account to use.
           Blank if not set [OPTIONAL]

For example:

    ./gcloud-snapshot.sh -a "my-service-account@test9q.iam.gserviceaccount.com"

### Project ID
By default snapshots are created with the default gcloud project id. To use a custom project id use the -j flag:

    Usage: ./gcloud-snapshot.sh [-j <project_id>]
    
    Options:
    
       -j  Project ID to use.
           Blank if not set [OPTIONAL]

For example:

    ./gcloud-snapshot.sh -j "my-test-project"

### Dry Run
The script can be run in dry run mode, which doesn't execute any create / delete commands, and prints out debug information.

    Usage: ./gcloud-snapshot.sh [-n <dry_run>]
    
    Options:
    
       -n  Dry run: causes script to print debug variables and doesn't execute any
           create / delete commands [OPTIONAL]

For example if you wanted to a test a gcloud filter expression against remote instances:

    ./gcloud-snapshot.sh -n -r -f "labels.auto_snapshot=true"

It would output something like:

    [2018-11-13 21:04:27]: Start of google-compute-snapshot
    [DEBUG]: OLDER_THAN=7
    [DEBUG]: REMOTE_CLAUSE=true
    [DEBUG]: PREFIX=gcs
    [DEBUG]: OPT_ACCOUNT=
    [DEBUG]: DRY_RUN=true
    [DEBUG]: DELETION_DATE=20181111
    [DEBUG]: INSTANCE_NAME=
    [2018-11-13 21:04:28]: Handling Snapshots for disk-1
    [DEBUG]: gcloud  compute disks snapshot disk-1 --snapshot-names gcs-disk-1-1542143067 --zone us-central1-c
    [2018-11-13 21:04:29]: Handling Snapshots for instance-1
    [DEBUG]: gcloud  compute disks snapshot instance-1 --snapshot-names gcs-instance-1-1542143067 --zone us-central1-c
    [2018-11-13 21:04:29]: End of google-compute-snapshot

## Saving output to Log

You can easily store the output from this command in a separate CRON log. Example cron for Debian based Linux:
```
0 5 * * * root /opt/google-compute-snapshot/gcloud-snapshot.sh >> /var/log/cron/snapshot.log 2>&1
```

The above command sends the output to a log file: `/var/log/cron/snapshot.log` - instructions for creating & managing the log file are below.

**Manage CRON Output**: You should then create a directory for all cron outputs and add it to logrotate:

- Create the folder, log file, and update the permissions:
``` 
sudo mkdir /var/log/cron 
sudo touch /var/log/cron/snapshot.log
sudo chgrp adm /var/log/cron/snapshot.log
sudo chmod 664 /var/log/cron/snapshot.log
```
- Create new entry in logrotate so cron files don't get too big :
```
sudo nano /etc/logrotate.d/cron
```
- Add the following text to the above file:
```
/var/log/cron/*.log {
    daily
    missingok
    rotate 14
    compress
    notifempty
    create 664 root adm
    sharedscripts
}
```

## License

MIT License

Copyright (c) 2018 Jack Segal

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
