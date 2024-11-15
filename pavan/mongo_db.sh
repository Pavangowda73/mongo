#!/bin/bash

# Variables
REPLICA_SET_NAME="rs0"
CACHE_SIZE="1GB"
MONGO_PORTS=(27017 27018 27019)
DB_PATH_BASE="/data/mongodb"


# Step 1: Set up MongoDB repository

echo "Setting up MongoDB repository for version 5.0"
cat <<EOF | sudo tee /etc/yum.repos.d/mongodb-org-5.0.repo
[mongodb-org-5.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/8/mongodb-org/5.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-5.0.asc
EOF

# Step 2: Install MongoDB

echo "Installing MongoDB version 5.0"
sudo yum install -y mongodb-org

sudo yum install -y mongodb-org-5.0.29 mongodb-org-database-5.0.29 mongodb-org-server-5.0.29 mongodb-org-shell-5.0.29 mongodb-org-mongos-5.0.29 mongodb-org-tools-5.0.29

exclude=mongodb-org,mongodb-org-database,mongodb-org-server,mongodb-mongosh,mongodb-org-mongos,mongodb-org-tools

mongod --version

sudo systemctl start mongod
 
sudo systemctl enable mongod


echo "MongoDB installation completed."

# Step 3: create mongod user an group-if not present
 
sudo groupadd mongod

sudo useradd -r -g mongod mongod


# Step 4: Configure MongoDB instances

echo "Configuring MongoDB replica set members..."
for port in "${MONGO_PORTS[@]}"; do
    db_path="$DB_PATH_BASE/$port"
    sudo mkdir -p $db_path
    sudo chown -R mongod:mongod $db_path

    cat <<EOF > mongod_$port.conf
systemLog:
  destination: file
  path: $db_path/mongod.log
  logAppend: true
storage:
  dbPath: $db_path
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1
net:
  bindIp: 65.0.102.146
  port: $port
security:
  javascriptEnabled: false
replication:
  replSetName: $REPLICA_SET_NAME
EOF

    sudo mongod --config mongod_$port.conf --fork
    echo "MongoDB instance started on port $port with WiredTiger cache size of $CACHE_SIZE."
done

# Step 5: Initiate the replica set

echo "Initiating replica set..."
mongo --port ${MONGO_PORTS[0]} <<EOF
rs.initiate({
  _id: "$REPLICA_SET_NAME",
  members: [
    { _id: 0, host: "65.0.102.146:${MONGO_PORTS[0]}" },
    { _id: 1, host: "65.0.102.146:${MONGO_PORTS[1]}" },
    { _id: 2, host: "65.0.102.146:${MONGO_PORTS[2]}", arbiterOnly: true }
  ]
})
EOF
echo "Replica set $REPLICA_SET_NAME initiated successfully."


