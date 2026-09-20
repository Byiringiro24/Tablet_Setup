but this have to be done on the frontend, in super admin, all to be done by super admin, also create document showing how to create tablet, device, and how to assign tablet with real examples





for deploying to server


# Backend
cd /var/www/ecare/backend
git pull origin New_Serverr
npm run build
pm2 restart ecare-backend --update-env

# Frontend
cd /var/www/ecare/frontend
git reset --hard origin/New_Serverr
echo "VITE_API_BASE_URL=https://backend.ecareafrica.net/api/v1" > .env
npm run build
nginx -s reload
