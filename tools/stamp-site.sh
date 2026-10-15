#!/usr/bin/env bash
# Cache-busting for GitHub Pages (it serves assets with max-age=600, so a browser can pair a NEW
# index.html with an OLD style.css for up to 10 minutes after a deploy). This stamps the CSS/JS
# links with a hash of their contents. Run it (./tools/stamp-site.sh) before committing any
# change to docs/assets.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../docs"
v=$(cat assets/style.css assets/app.js | sha1sum | cut -c1-8)
sed -i -E "s#(assets/(style\.css|app\.js))\?v=[0-9a-f]+#\1?v=${v}#g" index.html
echo "stamped index.html with v=${v}"
grep -oE 'assets/(style\.css|app\.js)\?v=[0-9a-f]+' index.html
