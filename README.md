
/usr/local/bin/kops create  -f /root/cluster.yaml --state s3://kops-state-bucket-ap-southeast-1

/usr/local/bin/kops create secret --name kops-lab.k8s.local sshpublickey admin -i /home/centos/tf.pub --state s3://kops-state-bucket-ap-southeast-1

usr/local/bin/kops update cluster kops-lab.k8s.local --yes --state s3://kops-state-bucket-ap-southeast-1
