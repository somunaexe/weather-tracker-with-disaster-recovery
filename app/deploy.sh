#!/bin/bash
# deploys the weather app to the EC2 instance

EC2_IP=$(cd ../terraform/environments && terraform output -raw ec2_public_ip)
KEY_FILE="../weather-tracker-key.pem"

echo "Deploying to EC2 at $EC2_IP..."

# install node and npm on the EC2 if not already there
ssh -i $KEY_FILE -o StrictHostKeyChecking=no ubuntu@$EC2_IP << 'ENDSSH'
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  sudo apt-get install -y nodejs
  sudo npm install -g pm2
ENDSSH

# copy app files to EC2
scp -i $KEY_FILE -r ./backend ubuntu@$EC2_IP:~/
scp -i $KEY_FILE -r ./frontend ubuntu@$EC2_IP:~/

# install dependencies and start the app with pm2
ssh -i $KEY_FILE ubuntu@$EC2_IP << ENDSSH
  cd ~/backend
  npm install
  pm2 stop weather-tracker 2>/dev/null || true
  WEATHER_API_KEY=$WEATHER_API_KEY \
  S3_BUCKET=weather-tracker-weather-data \
  AWS_REGION=eu-west-2 \
  pm2 start server.js --name weather-tracker
  pm2 save
ENDSSH

echo "Deployment complete! App running at http://$EC2_IP:3000"
