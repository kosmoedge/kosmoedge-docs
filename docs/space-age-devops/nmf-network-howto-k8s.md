# NMF services network configuration for Kubernetes

In order to configure the NMF Network appropriately for a cluster of independently deployed and containerized NMF apps
we need to first understand the NMF network internals. [NanoSatMO framework implementation](https://github.com/esa/nanosat-mo-framework) depends on [CCSDS MO services - ESA's Java implementation](https://github.com/esa/mo-services-java), which allows mission operation services to be specified in an implementation and communication agnostic manner.

## [Mission Operations — Message Abstraction Layer binding to TCP/IP](https://ccsds.org/Pubs/524x2b1.pdf)

The core of the MO service framework is its Message Abstraction Layer (MAL) which ensures interoperability between mission operation services. The MO services are specified in compliance to a reference service model, using an abstract service description language, the MAL. This is similar to how Web Services are specified in terms of Web Services Description Language WSDL. For each concrete deployment, the abstract service interface must be bound to the selected software implementation and communication technology.

MALTCP is an implementation for MAL transport binding using the TCP/IP protocol. It stands for "Message Abstraction Layer over TCP" and provides a standard for transferring data, especially in space and ground segment communications. It extends the functionality of TCP by adding specific header information and a layer of abstraction for MAL messages. 

## Configure NMF services to provision MALTCP functionality for a Kubernetes cluster

This transport binding makes use of the TCP/IP ip address and port number to route messages. Each message contains a source and destination URI, which contain the ip address and port of the provider and consumer respectively.

The protocol used is `maltcp://`. Message urls have the format `maltcp://ipaddr:port/serviceDescriptor`.

Each transport service which is launched, uses a configuration file to load necessary configuration parameters. As mentioned in the corresponding [documentation](https://github.com/esa/mo-services-java/blob/master/transports/transport-tcpip/README.md), in order to start using this transport binding, one has to set the properties `org.ccsds.moims.mo.mal.transport.tcpip.host`, `org.ccsds.moims.mo.mal.transport.tcpip.publishedHost`, `org.ccsds.moims.mo.mal.transport.tcpip.port` in the configuration file that is used by a consumer or provider. Another option is to use the `org.ccsds.moims.mo.mal.transport.tcpip.autohost` property to automatically assign the host and a port. 

The configuration used for our solution is explained below:
- `org.ccsds.moims.mo.mal.transport.tcpip.autohost`
    - ⚙️ **true** (default): Provides a default IP address for this host, using [getInetAdresses](https://docs.oracle.com/javase/8/docs/api/java/net/NetworkInterface.html#getInetAddresses--) method to get all or a subset of the InetAddresses bound to the network interface (loopback and Ipv6 Network interfaces are excluded) 
    - ✅ **false**: Permits us to manually set the host IP via other configuration properties

- `org.ccsds.moims.mo.mal.transport.tcpip.host`
    - ⚙️ **Specific IP** (e.g. 123.23.3.4): Ip this server is bound to, an adapter (host / IP Address) that the transport will use for incoming connections.
    - ✅ **0.0.0.0**: Used along with `org.ccsds.moims.mo.mal.transport.tcpip.publishedhost` so as the NMF app doesn't bind to a specific 
    IP for establishing connections, but resorts to using a hostname. In a Kubernetes environment there could be multiple applications, instances per application and deployment manifests. Manually assigning a specific IP for each NMF app is cumbersome and also requires alignment between the IP assigned to each pod and the IP defined in NMF app's transport properties.


- `org.ccsds.moims.mo.mal.transport.tcpip.publishedhost`
    - ✅ **Use hostname** (e.g. test_backend): Published IP or provider alias that will be used to generate services addresses. This property is required if `org.ccsds.moims.mo.mal.transport.tcpip.host` is set to `0.0.0.0` and defines the hostname used to communicate with the NMF service.

- `org.ccsds.moims.mo.mal.transport.tcpip.port` 
    - ⚙️ **Not defined**: The app is assigned the port 1024 in the bound IP (if there is one). If the port is already in use, then it increments until an available port is found
    - ✅ **Specific port** (e.g. 8080): We assign specific port, so that we can specifically configure Kubernetes Nodeport services for external access or ensure intranet communication

All the above configurations are rendered via [helm templates in a configmap resource](https://github.com/kosmoedge/deployments/blob/main/helm-charts/src/nmf-app/templates/configmap.yaml) using a [values.yaml file](https://github.com/kosmoedge/deployments/blob/main/helm-charts/src/nmf-app/values.yaml).

## Communicate with NMF service

### External access to the NMF service
It can be achieved by using the URI: `maltcp://{{hostname}}:{{NodePort port}}/{{servicename}}`, e.g. `maltcp://camera_service:3000/camera-app`. Using the `/etc/hosts` file we need to add a binding between the app's hostname and the Kubernetes cluster IP, e.g. `123.23.3.4 test_backend`
 
### Intranet communication between NMF services
It can be achieved by using the URI: `maltcp://{{hostname}}:{{app port}}/{{servicename}}`, e.g. `maltcp://camera-service:8080/camera-app`. The Kubernetes Service manifest names should match the hostname.
