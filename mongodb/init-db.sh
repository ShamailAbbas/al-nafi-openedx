
# Step 1 — Initiate the RS directly from inside pod-0:

kubectl exec mongodb-0 -n openedx -c mongodb -- mongosh --quiet --eval "
rs.initiate({
  _id: 'rs0',
  members: [{ _id: 0, host: 'mongodb-0.mongodb-headless.openedx.svc.cluster.local:27017', priority: 2 }]
})
"



# Step 2 — Verify it elected itself primary:

kubectl exec mongodb-0 -n openedx -c mongodb -- mongosh --quiet --eval "rs.status().myState"



# Step 3 — Create the admin user:

kubectl exec mongodb-0 -n openedx -c mongodb -- mongosh admin --quiet --eval "
db.createUser({
  user: 'openedx',
  pwd: 'Admin123@',
  roles: [{ role: 'root', db: 'admin' }]
})
"



# STEP 4 Add pod-1 and pod-2 to the replica set:

kubectl exec mongodb-0 -n openedx -c mongodb -- mongosh admin --quiet \
  -u openedx -p 'Admin123@' --authenticationDatabase admin --eval "
rs.add({ host: 'mongodb-1.mongodb-headless.openedx.svc.cluster.local:27017', priority: 1 });
rs.add({ host: 'mongodb-2.mongodb-headless.openedx.svc.cluster.local:27017', priority: 1 });
"



# Step 5 Create the OpenedX database users:

kubectl exec mongodb-0 -n openedx -c mongodb -- mongosh admin --quiet \
  -u openedx -p 'Admin123@' --authenticationDatabase admin --eval "
function ensureUser(dbName, user, pwd) {
  var d = db.getSiblingDB(dbName);
  if (d.system.users.findOne({ user: user, db: dbName })) { print('skip: ' + user + '@' + dbName); return; }
  d.createUser({ user: user, pwd: pwd, roles: [{ role: 'readWrite', db: dbName }] });
  print('created: ' + user + '@' + dbName);
}
ensureUser('openedx', 'openedx', 'Admin123@');
ensureUser('cs_comments_service', 'openedx', 'Admin123@');
ensureUser('xqueue', 'openedx', 'Admin123@');
"


# Step 6  Verify everything looks good:

kubectl exec mongodb-0 -n openedx -c mongodb -- mongosh admin --quiet \
  -u openedx -p 'Admin123@' --authenticationDatabase admin --eval "rs.status().members.map(m => m.host + ' state=' + m.stateStr)"