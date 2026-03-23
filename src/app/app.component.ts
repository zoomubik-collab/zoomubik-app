import { Component, OnInit } from '@angular/core';
import { IonApp } from '@ionic/angular/standalone';
import { Platform } from '@ionic/angular';
import { NativeService } from './services/native.service';

@Component({
  selector: 'app-root',
  templateUrl: 'app.component.html',
  styleUrls: ['app.component.scss'],
  imports: [IonApp],
})
export class AppComponent implements OnInit {
  constructor(
    private platform: Platform,
    private nativeService: NativeService  // <--- ¡Aquí está la inyección explícita!
  ) {}

  async ngOnInit(): Promise<void> {
    await this.platform.ready();
    // No abrir InAppBrowser: Capacitor cargará https://zoomubik.com vía server.url
  }
}
