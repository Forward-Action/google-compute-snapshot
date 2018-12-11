FROM google/cloud-sdk
RUN apt-get -y install curl
ADD gcloud-snapshot.sh /opt/gcloud-snapshot.sh
ADD entrypoint.sh /opt/entrypoint.sh
RUN chmod u+x /opt/gcloud-snapshot.sh /opt/entrypoint.sh
ENTRYPOINT /opt/entrypoint.sh
