#!/bin/bash
echo $(date) " - Starting Script"

RAND_STR=$(openssl rand -base64 48)
echo "Here's a random string: $RAND_STR"
