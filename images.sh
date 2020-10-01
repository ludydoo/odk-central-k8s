DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

mkdir -p $DIR/tmp
cd $DIR/tmp


if [ ! -d "$DIR/tmp/central" ] 
then
    git clone git@github.com:getodk/central.git
fi

cd central

git reset --hard
git submodule init
git submodule update

docker build -f enketo.dockerfile -t localhost:32000/enketo:latest . 
docker build -f service.dockerfile -t localhost:32000/service:latest . 