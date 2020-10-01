DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# generating enketo secrets
kubectl create secret generic enketo \
--namespace default \
--from-literal=enketo-secret=$(LC_ALL=C tr -dc '[:alnum:]' < /dev/urandom | head -c64 | base64 -w 0) \
--from-literal=enketo-less-secret=$(LC_ALL=C tr -dc '[:alnum:]' < /dev/urandom | head -c32 | base64 -w 0) \
--from-literal=enketo-api-key=$(LC_ALL=C tr -dc '[:alnum:]' < /dev/urandom | head -c128 | base64 -w 0)

# generating database secrets
kubectl create secret generic postgres \
--namespace default \
--from-literal=username=postgres \
--from-literal=password=$(LC_ALL=C tr -dc '[:alnum:]' < /dev/urandom | head -c128 | base64 -w 0)

# redis configs
mkdir -p $DIR/tmp
wget -O $DIR/tmp/redis-enketo-main.conf https://raw.githubusercontent.com/getodk/central/master/files/enketo/redis-enketo-main.conf
wget -O $DIR/tmp/redis-enketo-cache.conf https://raw.githubusercontent.com/getodk/central/master/files/enketo/redis-enketo-cache.conf

kubectl create configmap redis-enketo-main \
--from-file=redis.conf=$DIR/tmp/redis-enketo-main.conf

kubectl create configmap redis-enketo-cache \
--from-file=redis.conf=$DIR/tmp/redis-enketo-cache.conf

kubectl apply -f $DIR/app.yaml