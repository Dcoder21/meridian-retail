FROM node:22-bookworm-slim
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY app.js .
USER node
EXPOSE 4000
CMD ["node", "app.js"]
