#!/bin/bash

set -eux

sudo rm -fr devices/*
docker-compose up -d
