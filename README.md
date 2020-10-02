# odk-central-k8s : [OpenDataKit](https://opendatakit.org/) on Kubernetes.

`odk-central-k8s` helps with deploying [odk-central](https://github.com/getodk/central) to kubernetes.

# how it works

I'm cloning the `getodk/central` repository in a tmp folder. I'm using their docker images mostly intact. They don't have a docker image for either the `service` or their `enketo`. So these
two images are built using the `make docker-build` command. 

The biggest part of the work that has been done is around creating `ConfigMaps` that will 
take advantage of kubernetes `Secrets`. There is also a non-trivial `init-container` that
initialises and creates the database for use by `odk`. 

Deploying the cluster with `make k8s.deploy` will create the necessary `Secrets` and `ConfigMaps`
if they don't already exist. Then, some environment variables are piped through `envsubst` 
to a templated `k8s/*.yaml`, then applied using `kubectl`. 

All the resources are namespaced. There could potentially be multiple deployments, using 
different namespaces (configured in the `Makefile.properties`)

# remains to be done

- [ ] `enketo` sysadmin email
- [ ] security, ssl certificates (through `cert-manager`). 
- [ ] would be nice to have this behind a service mesh (istio) for tracing & monitoring
- [ ] logging. But I'm not sure yet how to plug in ELK stack with this existing codebase.
- [ ] automated database backup. I would prefer having the postgres db in a RDS database or some managed service with automated backup. 

# prerequisites

```
docker
kubectl
envsubst
helm (v3)
```

# how to use

The `Makefile` will use `kubectl` to interact with a kubernetes cluster. 
Make sure you have the correct context by doing `kubectl config use-context <my-context>`


```
$ make help
                                                                                  
Makefile to build and deploy odk-central                                          
                                                                                  
Usage:                                                                            
   make git.pull                       clones the odk-central git repository
   make docker.build                   builds the odk docker images
   make docker.push                    pushes the odk docker images
   make k8s.deploy                     deploys the odk app on kubernetes
   make k8s.teardown                   cleans up the kubernetes cluster from odk
   make backup.secrets                 backups the secrets
   make backup.secrets.restore         restores the secrets created with backup.secrets
   make monitoring.install             installs prometheus & grafana monitoring stack
   make monitoring.uninstall           uninstalls prometheus & grafana monitoring stack
   make dashboard.grafana.credentials  retrieves grafana credentials
   make dashboard.grafana              launch grafana dashboard
   make dashboard.prometheus           launch prometheus dashboard
```
# configuration

Edit `Makefile.properties` for available configuration

```
export DOMAIN ?= localhost                  # The odk domain
export DOCKER_REGISTRY ?= localhost:32000   # The docker registry
export IMAGE_VERSION ?= latest              # The docker image version tag
export NAMESPACE ?= hello                   # The kubernetes namespace to deploy into
```

# k8s components overview

|kind|name|description|
|----|----|-----------|
|Secret|postgres|__*created dynamically__. This secret holds the username and password of the postgres database superuser|
|Secret|postgres-odk|__*created dynamically__. This secret holds the username and password of the `odk` postgres user|
|Secret|enketo|__*created dynamically__. This secret holds the `enteko-secret`, `enteko-less-secret` and `enteko-api-key`|
|ConfigMap|redis-enketo-cache|__*created dynamically__. This file contains the redis configuration for the `redis-enteko-cache`. Retrieved from [here](https://raw.githubusercontent.com/getodk/central/master/files/enketo/redis-enketo-cache.conf)|
|ConfigMap|redis-enketo-main|__*created dynamically__. This file contains the redis configuration for the `redis-enteko-main`.  Retrieved from [here](https://raw.githubusercontent.com/getodk/central/master/files/enketo/redis-enketo-main.conf)|
|PersistentVolume|postgres-pv-volume|This volume contains the `postgres` data|
|PersistentVolumeClaim|postgres-pv-claim|This is the claim for the `postgres-pv-volume`|
|Deployment|postgres|The `postgres` database deployment (port 5432)|
|Service|postgres|The `postgres` service (port 5432)|
|Deployment|mail|The `mail` server deployment (port 25)|
|Service|mail|The `mail` service (port 25)|
|Deployment|service| The `service` (odk) deployment (port 8383)|
|Service|service| The `service` (odk) service (port 8383)|
|Deployment|pyxform|The `pyxform` deployment (port 80)|
|Service|pyxform|The `pyxform` service (port 80)|
|Deployment|enketo|The `enketo` deployment (port 8005)|
|Service|enketo|The `enketo` service (port 8005)|
|Deployment|enketo-redis-main|The `enketo-redis-main` redis deployment (port 6379)|
|Service|enketo-redis-main|The `enketo-redis-main` redis service (port 6379)|
|Deployment|enketo-redis-cache|The `enketo-redis-cache` redis deployment (port 6380)|
|Service|enketo-redis-cache|The `enketo-redis-cache` redis service  (port 6380)|
|Ingress|odk-ingress|The ingress to the cluster|
|ConfigMap|odk-config|Contains configuration overrides for `enketo` and `odk` server. Notably, adds a few `envsubst` variables to the json configurations. The `odk` server has a slightly tweaked start script to pass these env variables to `envsubst`. |
|ConfigMap|odk-config|Script to create and configure the `odk` database|

## backup

For now, the only backup available is for the secrets.

```
make backup.secrets          # will create a ./backup directory with the secret manifests
make backup.secrets.restore  # will restore the backed up secrets
```