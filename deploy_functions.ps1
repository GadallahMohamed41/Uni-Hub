# Firebase Cloud Functions Deployment Script
Write-Host "Deploying Firebase Cloud Functions..." -ForegroundColor Green

# Navigate to functions directory
Set-Location -Path "functions"

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Yellow
npm install

# Deploy functions
Write-Host "Deploying functions to Firebase..." -ForegroundColor Yellow
firebase deploy --only functions

# Return to root directory
Set-Location -Path ".."

Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Make sure you have Firebase CLI installed: npm install -g firebase-tools" -ForegroundColor White
Write-Host "2. Login to Firebase: firebase login" -ForegroundColor White
Write-Host "3. Run this script again if needed" -ForegroundColor White

Read-Host -Prompt "Press Enter to exit"