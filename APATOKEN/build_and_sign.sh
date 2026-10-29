#!/bin/bash
# Post-build script to graft icons and fix Info.plist
APP_PATH="$1"

# Copy icons
for icon in /Users/eternal/Apatoken_Work/graft_icons/*.png; do
    cp "$icon" "$APP_PATH/"
done

# Add CFBundleIcons to Info.plist
python3 -c "
import plistlib
plist_path = '$APP_PATH/Info.plist'
with open(plist_path, 'rb') as f:
    plist_data = plistlib.load(f)
plist_data['CFBundleIcons'] = {
    'CFBundlePrimaryIcon': {
        'CFBundleIconFiles': [
            'AppIcon29x29@2x.png',
            'AppIcon29x29@3x.png',
            'AppIcon40x40@2x.png',
            'AppIcon40x40@3x.png',
            'AppIcon60x60@2x.png',
            'AppIcon60x60@3x.png',
            'AppIcon1024.png'
        ],
        'UIPrerenderedIcon': True
    }
}
with open(plist_path, 'wb') as f:
    plistlib.dump(plist_data, f, fmt=plistlib.FMT_XML)
print('Info.plist updated')
"
