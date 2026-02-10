#!/bin/bash
set -e

MONGO_USER="openedx"
MONGO_PASS="Admin123@"

# Redirect all output to log file
exec > >(tee -a /var/log/mongodb-setup.log)
exec 2>&1

echo "=========================================="
echo "Starting MongoDB setup at $(date)"
echo "=========================================="

# -------------------------------
# Update system & install dependencies
# -------------------------------
echo "[$(date)] Updating system packages..."
apt-get update -y
apt-get install -y wget gnupg curl htop

# -------------------------------
# Install MongoDB 7.0
# -------------------------------
echo "[$(date)] Installing MongoDB 7.0..."
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
echo "deb [ arch=amd64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list
apt-get update -y
apt-get install -y mongodb-org

# -------------------------------
# Prepare data and log directories
# -------------------------------
echo "[$(date)] Preparing directories..."
mkdir -p /data/db /var/log/mongodb
chown -R mongodb:mongodb /data/db /var/log/mongodb

# -------------------------------
# Configure MongoDB config WITHOUT auth first
# -------------------------------
echo "[$(date)] Creating initial MongoDB config..."
cat > /etc/mongod.conf <<'EOF'
storage:
  dbPath: /data/db

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 127.0.0.1
EOF

# -------------------------------
# Start MongoDB WITHOUT auth
# -------------------------------
echo "[$(date)] Starting MongoDB without authentication..."
systemctl enable mongod
systemctl start mongod

# Wait for MongoDB to be ready
echo "[$(date)] Waiting for MongoDB to be ready..."
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  if mongosh --quiet --eval "db.adminCommand('ping').ok" > /dev/null 2>&1; then
    echo "[$(date)] MongoDB is ready!"
    break
  fi
  ATTEMPT=$((ATTEMPT + 1))
  echo "[$(date)] Attempt $ATTEMPT/$MAX_ATTEMPTS: MongoDB not ready yet, waiting..."
  sleep 5
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo "[$(date)] ERROR: MongoDB failed to start after $MAX_ATTEMPTS attempts"
  exit 1
fi

# -------------------------------
# Create admin user with write concern
# -------------------------------
echo "[$(date)] Creating admin user with write concern..."
mongosh admin --quiet --eval "
db.createUser({
  user: '${MONGO_USER}',
  pwd: '${MONGO_PASS}',
  roles: [{ role: 'root', db: 'admin' }]
});
"

if [ $? -ne 0 ]; then
  echo "[$(date)] ERROR: Failed to create admin user"
  exit 1
fi

# Force a checkpoint to ensure user is written to disk
echo "[$(date)] Forcing database checkpoint..."
mongosh admin --quiet --eval "db.adminCommand({fsync: 1})"
sleep 3

# Verify user exists before restarting
echo "[$(date)] Verifying user was created..."
USER_COUNT=$(mongosh admin --quiet --eval "db.system.users.countDocuments({user: '${MONGO_USER}'})" | tail -1)
echo "[$(date)] User count in database: $USER_COUNT"
if [ "$USER_COUNT" != "1" ]; then
  echo "[$(date)] ERROR: User was not created properly"
  mongosh admin --quiet --eval "db.system.users.find().forEach(printjson)"
  exit 1
fi
echo "[$(date)] User verified in database"

# -------------------------------
# Enable authentication in config
# -------------------------------
echo "[$(date)] Enabling authentication..."
cat > /etc/mongod.conf <<'EOF'
storage:
  dbPath: /data/db

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 0.0.0.0

security:
  authorization: enabled
EOF

# -------------------------------
# Restart MongoDB with auth enabled
# -------------------------------
echo "[$(date)] Restarting MongoDB with authentication enabled..."
systemctl restart mongod

# Wait for MongoDB to be ready after restart
echo "[$(date)] Waiting for MongoDB to restart..."
sleep 15

# Verify authentication works
echo "[$(date)] Verifying admin authentication..."
ATTEMPT=0
AUTH_SUCCESS=false
while [ $ATTEMPT -lt 10 ]; do
  if mongosh admin --quiet -u "${MONGO_USER}" -p "${MONGO_PASS}" --authenticationDatabase admin --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    echo "[$(date)] Admin authentication verified successfully!"
    AUTH_SUCCESS=true
    break
  fi
  ATTEMPT=$((ATTEMPT + 1))
  echo "[$(date)] Auth attempt $ATTEMPT/10 failed, retrying..."
  sleep 3
done

if [ "$AUTH_SUCCESS" = false ]; then
  echo "[$(date)] ERROR: Admin authentication failed"
  echo "[$(date)] Checking MongoDB logs..."
  tail -50 /var/log/mongodb/mongod.log
  exit 1
fi

# -------------------------------
# Create Open edX database users
# -------------------------------
echo "[$(date)] Creating database-specific users..."

mongosh admin -u "${MONGO_USER}" -p "${MONGO_PASS}" --authenticationDatabase admin --quiet <<'EOJS'
use openedx;
db.createUser({
  user: 'openedx',
  pwd: 'Admin123@',
  roles: [{ role: 'readWrite', db: 'openedx' }]
});

use cs_comments_service;
db.createUser({
  user: 'openedx',
  pwd: 'Admin123@',
  roles: [{ role: 'readWrite', db: 'cs_comments_service' }]
});

use xqueue;
db.createUser({
  user: 'openedx',
  pwd: 'Admin123@',
  roles: [{ role: 'readWrite', db: 'xqueue' }]
});

print('All database users created successfully');
EOJS

if [ $? -eq 0 ]; then
  echo "[$(date)] Database users created successfully"
else
  echo "[$(date)] ERROR: Failed to create database users"
  exit 1
fi

# -------------------------------
# Test connections
# -------------------------------
echo "[$(date)] Testing database connections..."
for DB in openedx cs_comments_service xqueue; do
  if mongosh "$DB" -u "${MONGO_USER}" -p "${MONGO_PASS}" --authenticationDatabase admin --quiet --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    echo "[$(date)] ✓ Successfully connected to $DB"
  else
    echo "[$(date)] ✗ Failed to connect to $DB"
  fi
done

# -------------------------------
# Create completion marker
# -------------------------------
touch /var/log/mongodb-setup-complete
echo "[$(date)] MongoDB setup completed successfully!"

# -------------------------------
# Display final information
# -------------------------------
INSTANCE_IP=$(hostname -I | awk '{print $1}')
echo "=========================================="
echo "MongoDB Installation Summary"
echo "=========================================="
echo "Admin User: ${MONGO_USER}"
echo "Password: ${MONGO_PASS}"
echo "Connection: mongodb://${MONGO_USER}:Admin123%40@${INSTANCE_IP}:27017/?authSource=admin"
echo "Log: /var/log/mongodb-setup.log"
echo "=========================================="