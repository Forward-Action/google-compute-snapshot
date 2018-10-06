# Automatic Snapshots for Google (gcloud) Compute Engine

Bash script for Automatic Snapshots and Cleanup on Google Compute Engine. **Requires no user input!**

Inspiration (and the installation instructions) taken from AWS script [aws-ec2-ebs-automatic-snapshot-bash](https://github.com/CaseyLabs/aws-ec2-ebs-automatic-snapshot-bash)

## How it works
gcloud-snapshot.sh will:

- Determine the Instance ID of the Google Compute Engine server on which the script runs
- Get all the Disk IDs attached to that instance
- Take a snapshot of each Disk
- The script will then delete all associated snapshots taken by the script for the Instance that are older than 7 days (optional: [default snapshot retention can be changed by using -d flag](#snapshot-retention))


## Prerequisites
* `cURL` must be installed
* The VM must have the sufficient gcloud permissions, including "compute" set to "enabled":

	[	http://stackoverflow.com/questions/31905966/gcloud-compute-list-networks-error-some-requests-did-not-succeed-insufficie#31928399](http://stackoverflow.com/questions/31905966/gcloud-compute-list-networks-error-some-requests-did-not-succeed-insufficie#31928399)
* The version of gcloud is up to date: `gcloud components update` 
* You are authenticated with gcloud - normally this happens automatically, but some users get the error "Insufficient Permission" and need to authenticate: `sudo gcloud auth login`

## Installation

ssh on to the server you wish to have backed up

**Install Script**: Download the latest version of the snapshot script and make it executable:
```
cd ~
wget https://raw.githubusercontent.com/jacksegal/google-compute-snapshot/master/gcloud-snapshot.sh
chmod +x gcloud-snapshot.sh
sudo mkdir -p /opt/google-compute-snapshot
sudo mv gcloud-snapshot.sh /opt/google-compute-snapshot/
```

**To manually test the script:**
```
sudo /opt/google-compute-snapshot/gcloud-snapshot.sh
```

## Usage
### Snapshot Retention
By default snapshots will be kept for 7 days, however they can be kept for longer / shorter, by using the the -d flag:

    Usage: ./snapshot.sh [-d <days>]
    
    Options:
    
       -d  Number of days to keep snapshots. Snapshots older than this number deleted.
           Default if not set: 7 [OPTIONAL]

### Matching on specific disks
By default, snapshots will be created for all attached disks.  To only snapshot specific disks (ie. data volumes while skipping boot volumes), use the -t flag:

    Usage: ./snapshot.sh [-t <label>]
    
    Options:
    
       -t  Only back up disks that have this specified label with value set to 'true'

Example: If you set the label to "auto_snapshot", only disks matching this key/value pair will be snapshotted:

    auto_snapshot=true

This also allows you to bake snapshotting into your Google images by setting a cron job with a label on every image you create, and then you can set a label on the volumes you want to
snapshot in your infrastructure management tool (Terraform) to selectively snapshot them.

### Choosing instance for the attached disks
By default, all the disks attached to the calling instance will be snapshotted. To change this behaviour:

    ./gcloud-compute-snapshot.sh [-i <instance_name]

    Note: The calling instance (rather than the named instance) needs to have the correct gcloud permissions

## Automation
**Setup CRON**: You should then setup a cron job in order to schedule a daily backup. Example cron for Debian based Linux:
```
0 5 * * * root /opt/google-compute-snapshot/gcloud-snapshot.sh >> /var/log/cron/snapshot.log 2>&1
```

Please note: the above command sends the output to a log file: `/var/log/cron/snapshot.log` - instructions for creating & managing the log file are below.

**Manage CRON Output**: You should then create a directory for all cron outputs and add it to logrotate:

- Create new directory:
``` 
sudo mkdir /var/log/cron 
```
- Create empty file for snapshot log:
```
sudo touch /var/log/cron/snapshot.log
```
- Change permissions on file:
```
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

## Snapshot Retention
By default snapshots will be kept for 7 days, however they can be kept for longer / shorter, by using the the -d flag:

    Usage: ./snapshot.sh [-d <days>]
    
    Options:
    
       -d  Number of days to keep snapshots. Snapshots older than this number deleted.
           Default if not set: 7 [OPTIONAL]

## Matching on specific disks
By default, snapshots will be created for all attached disks.  To only snapshot specific disks (ie. data volumes while skipping boot volumes), use the -t flag:

    Usage: ./snapshot.sh [-t <label>]
    
    Options:
    
       -t  Only back up disks that have this specified label with value set to 'true'

Example: If you set the label to "auto_snapshot", only disks matching this key/value pair will be snapshotted:

    auto_snapshot=true

Use -T for a more flexible way to specify the disks to snapshot.
    Usage: ./gcloud-compute-snapshot.sh [-T <gcloud_filter_expression>]

    Options:

       -T    Only back up disks returned from querying with this filter. Uses gcloud filter expressions"
             If both -t and -T are used, both terms are joined by the operator AND"

Example: `./gcloud-compute-snapshot.sh -t auto_snapshot -T "sizeGb = 10 AND name: ubuntu"`. Attached disks matching this expression will be snapshotted

    --format="labels.auto_snapshot=true AND sizeGb = 10 AND name: ubuntu"

This also allows you to bake snapshotting into your Google images by setting a cron job with a label on every image you create, and then you can set a label on the volumes you want to
snapshot in your infrastructure management tool (Terraform) to selectively snapshot them.

## License

MIT License

Copyright (c) 2018 Jack Segal

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
