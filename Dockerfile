FROM node:10

WORKDIR /usr/src/app

COPY . ./

RUN npm install

EXPOSE 3000

CMD [ "node", "src/000.js"]