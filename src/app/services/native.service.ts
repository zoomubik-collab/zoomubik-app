import { Injectable, inject } from '@angular/core';
import { Share } from '@capacitor/share';
import { Camera, CameraResultType, CameraSource } from '@capacitor/camera';
import { LocalNotifications } from '@capacitor/local-notifications';
import { Platform } from '@ionic/angular';

@Injectable({
  providedIn: 'root'
})
export class NativeService {
  private platform = inject(Platform);

  constructor() {
    this.initializeNotifications();
  }

  async shareContent(title: string, text: string, url?: string) {
    try {
      await Share.share({
        title: title,
        text: text,
        url: url,
        dialogTitle: 'Compartir'
      });
    } catch (error) {
      console.error('Error compartiendo:', error);
    }
  }

  async takePicture(): Promise<string | null> {
    try {
      const image = await Camera.getPhoto({
        quality: 90,
        allowEditing: true,
        resultType: CameraResultType.DataUrl,
        source: CameraSource.Camera
      });
      return image.dataUrl || null;
    } catch (error) {
      console.error('Error tomando foto:', error);
      return null;
    }
  }

  async pickPhoto(): Promise<string | null> {
    try {
      const image = await Camera.getPhoto({
        quality: 90,
        allowEditing: true,
        resultType: CameraResultType.DataUrl,
        source: CameraSource.Photos
      });
      return image.dataUrl || null;
    } catch (error) {
      console.error('Error seleccionando foto:', error);
      return null;
    }
  }

  private async initializeNotifications() {
    if (this.platform.is('ios') || this.platform.is('android')) {
      try {
        const permission = await LocalNotifications.requestPermissions();
        if (permission.display === 'granted') {
          console.log('Permisos de notificaciones otorgados');
        }
      } catch (error) {
        console.error('Error solicitando permisos de notificaciones:', error);
      }
    }
  }

  async sendNotification(title: string, body: string, delaySeconds: number = 5) {
    try {
      await LocalNotifications.schedule({
        notifications: [
          {
            title: title,
            body: body,
            id: Math.floor(Math.random() * 10000),
            schedule: { at: new Date(Date.now() + delaySeconds * 1000) },
            smallIcon: 'ic_stat_icon_config_sample',
            iconColor: '#488AFF'
          }
        ]
      });
    } catch (error) {
      console.error('Error enviando notificación:', error);
    }
  }

  async cancelAllNotifications() {
    try {
      await LocalNotifications.cancel({ notifications: [] });
    } catch (error) {
      console.error('Error cancelando notificaciones:', error);
    }
  }
}
