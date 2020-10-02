FROM node:12.6.0 as intermediate

COPY ./ ./
RUN files/prebuild/write-version.sh
RUN files/prebuild/build-frontend.sh

FROM nginx

EXPOSE 80
COPY --from=intermediate client/dist/ /usr/share/nginx/html
COPY --from=intermediate /tmp/version.txt /usr/share/nginx/html/


