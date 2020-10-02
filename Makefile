include Makefile.properties

help:
	@echo '                                                                                         '
	@echo 'Makefile to build and deploy odk-central                                                 '
	@echo '                                                                                         '
	@echo 'Usage:                                                                                   '
	@echo '   make git.pull                       clones the odk-central git repository             '                                                
	@echo '   make docker.build                   builds the odk docker images                      '    
	@echo '   make docker.push                    pushes the odk docker images                      '   
	@echo '   make k8s.deploy                     deploys the odk app on kubernetes                 '    
	@echo '   make k8s.teardown                   cleans up the kubernetes cluster from odk         '    
	@echo '   make backup.secrets                 backups the secrets                               '
	@echo '   make backup.secrets.restore         restores the secrets created with backup.secrets  '
	@echo '   make monitoring.install             installs prometheus & grafana monitoring stack    '
	@echo '   make monitoring.uninstall           uninstalls prometheus & grafana monitoring stack  '
	@echo '   make dashboard.grafana.credentials  retrieves grafana credentials                     '
	@echo '   make dashboard.grafana              launch grafana dashboard                          '
	@echo '   make dashboard.prometheus           launch prometheus dashboard                       '     
	@echo '                                                                                         '

directories:
	@echo creating tmp directory
	@[ -d "tmp" ] && echo tmp directory already exists. skipping || mkdir -p tmp

git.pull: directories
	@echo cloning odk/central repository
	@cd tmp; [ -d "central" ] && echo repository already exists. skipping || git clone git://github.com/getodk/central.git
	@echo resetting git repository
	cd tmp/central; git reset --hard
	@echo retrieving submodules
	cd tmp/central; git submodule init
	cd tmp/central; git submodule update

docker.build: git.pull
	cd tmp/central;	docker build -f enketo.dockerfile -t $(DOCKER_REGISTRY)/enketo:$(IMAGE_VERSION) . 
	cd tmp/central; docker build -f service.dockerfile -t $(DOCKER_REGISTRY)/service:$(IMAGE_VERSION) . 
	cd tmp/central; docker build -f nginx.dockerfile -t $(DOCKER_REGISTRY)/frontend:$(IMAGE_VERSION) . 

docker.push: docker.build
	docker push $(DOCKER_REGISTRY)/enketo:$(IMAGE_VERSION) 
	docker push $(DOCKER_REGISTRY)/service:$(IMAGE_VERSION)
	docker push $(DOCKER_REGISTRY)/frontend:$(IMAGE_VERSION)

k8s.deploy: git.pull

	@kubectl get namespace $(NAMESPACE) \
	&& echo namespace $(NAMESPACE) already exists \
	|| kubectl create namespace $(NAMESPACE)

	# generating enteko secrets (if they don't already exist)
	@echo generating enteko secrets
	@kubectl get secret enketo --namespace="$(NAMESPACE)" \
	&& echo "enketo" secret already exists \
	|| kubectl create secret generic enketo \
	--namespace="$(NAMESPACE)" \
	--from-literal=enketo-secret=$(shell LC_ALL=C tr -dc '[:alnum:]' < /dev/urandom | head -c64) \
	--from-literal=enketo-less-secret=$(shell LC_ALL=C tr -dc '[:alnum:]' < /dev/urandom | head -c32) \
	--from-literal=enketo-api-key=$(shell LC_ALL=C tr -dc '[:alnum:]' < /dev/urandom | head -c128)

	# generating postgres-odk secrets (if they don't already exist)
	@echo generating postgres-odk secrets
	@kubectl get secret postgres-odk --namespace="$(NAMESPACE)"\
	&& echo "postgres-odk" secret already exists \
	|| kubectl create secret generic postgres-odk \
	--namespace="$(NAMESPACE)" \
	--from-literal=db=odk \
	--from-literal=username=odk \
	--from-literal=password=$(shell LC_ALL=C tr -dc '[:alnum:]' < /dev/urandom | head -c64)

	# generating superuser database secrets (if they don't already exist)
	@echo generating superuser database secrets
	@kubectl get secret postgres --namespace="$(NAMESPACE)" \
	&& echo "postgres" secret already exists \
	|| kubectl create secret generic postgres \
	--namespace="$(NAMESPACE)" \
	--from-literal=username=postgres \
	--from-literal=password=$(shell LC_ALL=C tr -dc '[:alnum:]' < /dev/urandom | head -c128)
	
	# create redis configs (if they don't already exist)
	kubectl get configmap redis-enketo-main --namespace="$(NAMESPACE)" \
	&& echo "redis-enketo-main" secret already exists \
	|| kubectl create configmap redis-enketo-main \
	--namespace="$(NAMESPACE)" \
	--from-file=redis.conf=tmp/central/files/enketo/redis-enketo-main.conf

	kubectl get configmap redis-enketo-cache --namespace="$(NAMESPACE)" \
	&& echo "redis-enketo-cache" secret already exists \
	|| kubectl create configmap redis-enketo-cache \
	--namespace="$(NAMESPACE)" \
	--from-file=redis.conf=tmp/central/files/enketo/redis-enketo-cache.conf

	# apply manifests
	cat k8s/* \
	| envsubst '$${DOMAIN},$${DOCKER_REGISTRY},$${IMAGE_VERSION},$${NAMESPACE},$${SYSADMIN_EMAIL}' \
	| kubectl apply --namespace="$(NAMESPACE)" -f -

k8s.teardown:
	-cat k8s/* | kubectl delete --namespace="$(NAMESPACE)" -f -
	-kubectl delete secret postgres --namespace="$(NAMESPACE)"
	-kubectl delete secret postgres-odk --namespace="$(NAMESPACE)"
	-kubectl delete secret enketo --namespace="$(NAMESPACE)"	
	-kubectl delete configmap redis-enketo-cache --namespace="$(NAMESPACE)"
	-kubectl delete configmap redis-enketo-main --namespace="$(NAMESPACE)"
	
backup.secrets:
	mkdir -p backup/$(NAMESPACE)
	kubectl --namespace="$(NAMESPACE)" \
	get secret enketo postgres-odk postgres \
	-o yaml > backup/$(NAMESPACE)/secrets.yaml

backup.secrets.restore:
	kubectl --namespace="$(NAMESPACE)" create -f backup/$(NAMESPACE)/secrets.yaml

monitoring.install:
	-kubectl create ns monitoring
	helm repo add prometheus-community https://	prometheus-community.github.io/helm-charts
	helm repo add stable https://kubernetes-charts.storage.googleapis.com/
	helm repo update
	helm install --namespace monitoring monitor prometheus-community/kube-prometheus-stack 

monitoring.uninstall:
	helm uninstall --namespace monitoring monitor
	kubectl delete ns monitoring

dashboard.grafana.credentials:
	@echo -n username: && kubectl get secret -n monitoring monitor-grafana -o jsonpath={.data.admin-user} | base64 -d && echo
	@echo -n password: && kubectl get secret -n monitoring monitor-grafana -o jsonpath={.data.admin-password} | base64 -d && echo

dashboard.grafana:
	@echo Grafana available at http://localhost:3000
	@kubectl port-forward -n monitoring $$(kubectl -n monitoring get pod --selector app.kubernetes.io/name=grafana -o jsonpath={.items[].metadata.name}) 3000:3000

dashboard.prometheus:
	@echo Prometheus available at http://localhost:9090
	@kubectl port-forward -n monitoring $$(kubectl -n monitoring get pod --selector app=prometheus -o jsonpath={.items[].metadata.name}) 9090:9090

validate:
	# test manifests
	cat k8s/* \
	| envsubst '$${DOMAIN},$${DOCKER_REGISTRY},$${IMAGE_VERSION},$${NAMESPACE},$${SYSADMIN_EMAIL}' \
	| kubectl apply --dry-run=client --namespace="$(NAMESPACE)" -f -