#!/bin/bash

APP_IPFS_DIRECTORY=/opt/jsipfs
IPFS_REPO_DIR=/opt/jsipfs/repo

PM2_LOGS=/opt/jsipfs/pm2logs.log
PM2_ECOSYSTEM_CONFIG=/opt/jsipfs/ecosystem.config.js

S3_BUCKET=bucketname
S3_ACCESSKEYID=accesskey
S3_SECRETKEY=secretaccesskey

print_status() {
	echo
	echo "++++ $1"
	echo
}

bail() {
echo "[ERROR] Error in the script execution. exiting ..."
exit 1
}

exec_cmd_nobail() {
   bash -c "$1"
}

exec_cmd() {
    exec_cmd_nobail "$1" || bail
}

is_root_user() {
	if ! [ $(id -u) = 0 ]; then
	   print_status "This script must be run as root user"
	   exit 1
	fi
}

setup_ipfss3_directory() {
	print_status "Creating app directories"
	exec_cmd "mkdir -p $APP_IPFS_DIRECTORY"
	exec_cmd "mkdir -p $IPFS_REPO_DIR"
}

install_nodejs_and_dependencies() {

	if ( ! dpkg -l | grep -q "nodejs" ); then
		print_status "Installing nodejs dependencies"
		exec_cmd "apt-get install curl python-software-properties -y > /dev/null 2>&1"
		exec_cmd "curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -"

		print_status "Installing nodejs"
		exec_cmd "apt-get install nodejs -y > /dev/null 2>&1"
		print_status "Done"
	fi
}

install_npm_required_packages() {
	print_status "Installing required npm packages"
	exec_cmd "cd $APP_IPFS_DIRECTORY; npm init --yes; sudo npm install aws-sdk datastore-s3 ipfs; sudo npm install pm2 --global"
}

get_ipfss3_sourcecode() {
	print_status "Downloading jsipfs source code"
	exec_cmd "curl -sL -o $APP_IPFS_DIRECTORY/jsipfs_s3.js https://raw.githubusercontent.com/scarsman/bisagunsa/master/jsipfs_s3.js"
}

setup_pm2_config() {

print_status "Configuring pm2 for node jsipfs_s3"
cat << EOF > $PM2_ECOSYSTEM_CONFIG
module.exports = {
  apps : [{
    name: "jsipfs3",
    script: "./jsipfs_s3.js",
    watch: false,
    time: true,
    log_file: "$PM2_LOGS",
    env: {
      IPFSREPO: "$IPFS_REPO_DIR",
      BUCKETNAME: "$S3_BUCKET",
      BUCKETACCESSKEYID: "$S3_ACCESSKEYID",
      BUCKETSECRETACCESSKEY: "$S3_SECRETKEY"
    }
  }]
}
EOF
}

start_jsipfss3_pm2() {
	print_status "Starting pm2 - jsipfs3"
	exec_cmd "cd $APP_IPFS_DIRECTORY; pm2 start ecosystem.config.js"
	print_status "Done"
}

#todo add nginx configuration/basic auth

is_root_user
setup_ipfss3_directory
install_nodejs_and_dependencies
install_npm_required_packages
get_ipfss3_sourcecode
setup_pm2_config
start_jsipfss3_pm2
