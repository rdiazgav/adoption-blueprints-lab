FROM registry.access.redhat.com/ubi9/nodejs-20:latest
WORKDIR /opt/app-root/src
USER 1001
COPY package.json .
RUN npm install
COPY server.js .
COPY public/ ./public/
EXPOSE 3000
CMD ["node", "server.js"]
