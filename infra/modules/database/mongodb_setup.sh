#!/bin/bash
set -e

MONGO_USER="openedx"
MONGO_PASS="Admin123@"


# -------------------------------
# Update system & install dependencies
# -------------------------------
apt-get update -y
apt-get install -y wget gnupg curl htop

# -------------------------------
# Install MongoDB 7.0
# -------------------------------
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
echo "deb [ arch=amd64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list
apt-get update -y
apt-get install -y mongodb-org

# -------------------------------
# Prepare data and log directories
# -------------------------------
mkdir -p /data/db /var/log/mongodb
chown -R mongodb:mongodb /data/db /var/log/mongodb

# -------------------------------
# Start MongoDB WITHOUT auth
# -------------------------------
systemctl enable mongod
systemctl start mongod
sleep 100

# -------------------------------
# Create admin user
# -------------------------------
mongosh admin --eval "
db.createUser({
  user: '$MONGO_USER',
  pwd: '$MONGO_PASS',
  roles: [{ role: 'root', db: 'admin' }]
});
"

# -------------------------------
# Enable authentication in config
# -------------------------------
cat > /etc/mongod.conf <<EOF
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
systemctl restart mongod
sleep 5

# -------------------------------
# Create Open edX databases and users
# -------------------------------
mongosh admin -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase admin --eval "
use openedx; db.createUser({ user: '$MONGO_USER', pwd: '$MONGO_PASS', roles: [{ role: 'readWrite', db: 'openedx' }] });
use cs_comments_service; db.createUser({ user: '$MONGO_USER', pwd: '$MONGO_PASS', roles: [{ role: 'readWrite', db: 'cs_comments_service' }] });
use xqueue; db.createUser({ user: '$MONGO_USER', pwd: '$MONGO_PASS', roles: [{ role: 'readWrite', db: 'xqueue' }] });
"

# -------------------------------
# Final message
# -------------------------------
echo "MongoDB installation complete!"
echo "Admin user: $MONGO_USER"
echo "Password: $MONGO_PASS"
echo "Connection string: mongodb://$MONGO_USER:$MONGO_PASS@localhost:27017/?authSource=admin"
