# URL Scheme Setup for actionly-companion

The code is ready to handle URL scheme triggers. You just need to register the URL scheme in Xcode.

## Xcode Configuration Steps

1. **Open the project in Xcode**
   - Open `actionly-companion.xcodeproj`

2. **Select the target**
   - Click on the project in the left sidebar
   - Select the "actionly-companion" target

3. **Go to the Info tab**
   - Click on the "Info" tab at the top

4. **Add URL Types**
   - Scroll down to find "URL Types" section
   - Click the "+" button to add a new URL type

5. **Configure the URL scheme**
   - **Identifier**: `com.actionly.companion`
   - **URL Schemes**: `actionly`
   - **Role**: Editor

6. **Build and run the app**

## Testing the URL Scheme

Once configured, you can test it from Terminal:

```bash
# Open the actionly-companion window
open "actionly://trigger"

# Or simply
open "actionly://"
```

## How it works

- When any URL with the `actionly://` scheme is opened, macOS will launch (or activate) your app
- The app will show the input window
- The user can then type their prompt manually

## Integration with Logitech Plugin

Your Logitech plugin should simply call:

```javascript
// JavaScript example
window.open('actionly://trigger');

// Or use a shell command
system("open actionly://trigger");
```

The exact implementation depends on the Logitech plugin API, but the URL to trigger is always: `actionly://trigger`
