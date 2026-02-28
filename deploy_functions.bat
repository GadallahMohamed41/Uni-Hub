@echo off
echo Deploying Firebase Cloud Functions...
cd functions
npm install
firebase deploy --only functions
cd ..
echo Deployment complete!
pause