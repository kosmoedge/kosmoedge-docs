To use kubectl:
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
It was added in the ~/.bashrc
To connect to supervisor running behind a ClusterIP service do the following:
1. Port Forward supervisor’s service
kubectl port-forward svc/supervisor 32325:32325 -n kosmoedge
2. SSH Tunnel to the port on remote host
ssh -N -L 32325:localhost:32325 kosmoedge@192.168.2.26


use -fN if you want to run in the background.

To take picture:
Add hosts to /etc/hosts for camera and supervisor - NMF needs the correct host to function so only IP will not work 
run CTT by executing nanosat-mo-framework\sdk\sdk-package\target\nmf-sdk-2.1.0-SNAPSHOT\home\nmf\consumer-test-tool\consumer-test-tool.sh
Fetch information for camera directory: maltcp://camera.kosmoedge:32326/space-module-Directory
Connect to Selected Provider
Got to Action Service tab, select TakeSnap.jpg and press submit action


To copy picture from pod to k3s node: 
kubectl cp nmf-camera-nmf-camera-574f7c677b-s95xs:/opt/space-module/toGround/20240324_183349_myPicture.jpg ./test.jpg
