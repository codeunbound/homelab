set -e  # Stop on error
UPLOAD_SRC="/opt/immich/upload"
UPLOAD_DST="/mnt/photos/immich"
ENV_FILE="/opt/immich/.env"

echo "🛑 Stopping Immich services..."
systemctl stop immich-web immich-ml

echo "📄 Checking if target directory exists..."
if [ ! -d "$UPLOAD_DST" ]; then
    echo "❌ Directory $UPLOAD_DST does not exist. Please mount your NAS first!"
    exit 1
fi

echo "⚙️ Updating .env file..."
if grep -q "^IMMICH_MEDIA_LOCATION=" "$ENV_FILE"; then
    sed -i "s|^IMMICH_MEDIA_LOCATION=.*|IMMICH_MEDIA_LOCATION=$UPLOAD_DST|" "$ENV_FILE"
else
    echo "IMMICH_MEDIA_LOCATION=$UPLOAD_DST" >> "$ENV_FILE"
fi

echo "📦 Moving existing data..."
mkdir -p "$UPLOAD_DST"
cp -a "$UPLOAD_SRC/"* "$UPLOAD_DST"/ || echo "⚠️ No existing files found to move."

echo "🔗 Creating new symlinks..."
rm -f /opt/immich/app/upload
rm -f /opt/immich/app/machine-learning/upload
ln -sf "$UPLOAD_DST" /opt/immich/app/upload
ln -sf "$UPLOAD_DST" /opt/immich/app/machine-learning/upload

echo "🔒 Adjusting ownership..."
chown -R immich:immich /opt/immich

# echo "🧠 Updating media paths in the Immich database..."
# cd /opt/immich/app/bin
# if [ -f "./immich-admin" ]; then
#     ./immich-admin change-media-location || echo "⚠️ Command may have failed — please verify manually."
# else
#     echo "⚠️ immich-admin not found, skipping this step."
# fi

echo "🚀 Restarting Immich services..."
systemctl start immich-ml immich-web

echo "🧩 Checking log output..."
tail -n 10 /var/log/immich/web.log || true

echo "🧹 Removing old upload folder..."
rm -rf "$UPLOAD_SRC"

echo "✅ Done!"
echo "Immich now uses $UPLOAD_DST as its upload directory."