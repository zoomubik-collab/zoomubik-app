import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.zoomubik.app',
  appName: 'Zoomubik',
  webDir: 'www',
  server: {
    allowNavigation: ['zoomubik.com', '*.zoomubik.com']
  }
};

export default config;
