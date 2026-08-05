FROM gcr.io/distroless/nodejs24-debian13:nonroot
WORKDIR /app
COPY --chown=65532:65532 package.json ./
COPY --chown=65532:65532 src ./src
USER 65532:65532
ENV NODE_ENV=production PORT=3000
EXPOSE 3000
CMD ["src/server.js"]
