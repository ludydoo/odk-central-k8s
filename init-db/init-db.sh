CREATE USER jubilant WITH PASSWORD 'jubilant';
CREATE DATABASE jubilant with owner=jubilant encoding=UTF8;
\c jubilant;
CREATE EXTENSION IF NOT EXISTS CITEXT;
CREATE EXTENSION IF NOT EXISTS pg_trgm;