#!/bin/sh

echo "Initialize MysSQL"
./scripts/setup_mysql

echo "Initialize Mongo"
./scripts/setup_mongo

echo "Initialize shock"
./scripts/setup_shock

echo "Initialize Workspace"
./scripts/setup_Workspace 

echo "Initialize wstypes"
./scripts/setup_wstypes
