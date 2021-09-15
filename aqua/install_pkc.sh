#!/usr/bin/env bash

set -ex

WALLET_ADDRESS="$1"

BASE_EXTENSIONS="CategoryTree,Cite,CiteThisPage,ConfirmEdit,EmbedVideo,Gadgets,ImageMap,InputBox,Interwiki,LocalisationUpdate,MultimediaViewer,Nuke,OATHAuth,PageImages,ParserFunctions,PDFEmbed,PdfHandler,Poem,Renameuser,ReplaceText,Scribunto,SecureLinkFixer,SpamBlacklist,SyntaxHighlight_GeSHi,TemplateData,TextExtracts,TitleBlacklist,WikiEditor"
EXTENSIONS="$BASE_EXTENSIONS,PDFEmbed,DataAccounting,MW-OAuth2Client"

admin_password="$(openssl rand -base64 20)"

echo "Your admin password is $admin_password"

# TODO install intersection extension
# --quiet
# --wiki=domain_id
# Use --dbpassfile and --passfile for higher security
php maintenance/install.php --server="http://localhost:9352" \
                --dbuser=wikiuser \
                --dbpass=example \
                --dbname=my_wiki \
                --dbserver="database" \
                --pass="$admin_password" \
                --skins=Medik \
                --with-extensions="$EXTENSIONS" \
                --scriptpath="" \
                "Personal Knowledge Container" \
                "$WALLET_ADDRESS"

# Extend settings
cat aqua/extraAquaSettings.php >> LocalSettings.php

# Disable VisualEditor
sed -i "s/wfLoadExtension( 'VisualEditor' );/#wfLoadExtension( 'VisualEditor' );/" LocalSettings.php

# Enable file upload
sed -i "s/wgEnableUploads = false;/wgEnableUploads = true;/" LocalSettings.php

# Insert domain ID to LocalSettings.php.
# The first openssl command is for entropy source. The second openssl command
# is for doing a sha3sum. The xxd command converts the sha sum in binary to hex
# format. And finally the head commands returns only the first 10 characters.
DOMAIN_ID=$(openssl rand -hex 64 | openssl dgst -sha3-512 -binary | xxd -p -c 256 | head -c 10)
echo "\$wgDADomainID = '$DOMAIN_ID';" >> LocalSettings.php

# Insert smart contract address to LocalSettings.php.
echo "\$wgDASmartContractAddress = '0x45f59310ADD88E6d23ca58A0Fa7A55BEE6d2a611';" >> LocalSettings.php

# Insert witness network to LocalSettings.php
cat <<EOF >> LocalSettings.php
# Possible values are:
# - mainnet
# - goerli
# - See more at https://besu.hyperledger.org/en/stable/Concepts/NetworkID-And-ChainID/
\$wgWitnessNetwork = 'goerli';
EOF

# Set required permissions to store images
chown -R www-data:www-data /var/www/html/images

# Update sidebar
php maintenance/edit.php -s "Use PKC sidebar" -u Admin MediaWiki:Sidebar < aqua/sidebar.wiki

# Populate a page
php maintenance/edit.php -a -u Admin "Moores Law" < aqua/MooresLaw.wiki

# Move the actual LocalSettings.php file to a backup folder that persists after a
# docker-compose down.
MW_DIR=/var/www/html
mv $MW_DIR/LocalSettings.php /backup/LocalSettings.php
ln -s /backup/LocalSettings.php $MW_DIR/LocalSettings.php
