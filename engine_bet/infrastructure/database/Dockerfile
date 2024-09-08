FROM postgres:latest
ENV POSTGRES_DB dbTarget
ENV POSTGRES_USER postgres
ENV POSTGRES_PASSWORD F4milia_2023_
COPY dbTarget.sql /docker-entrypoint-initdb.d/
# RUN docker build -t postgres_image_dbtarget .
# # RUN docker run --name postgres_dbtarget -d -p 7543:5432 postgres_image_dbtarget