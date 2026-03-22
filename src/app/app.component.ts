import { Component, OnInit, inject } from '@angular/core';
import { IonApp } from '@ionic/angular/standalone';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';
import { Platform } from '@ionic/angular';
import { NativeService } from './services/native.service';
import { WebViewService } from './services/webview.service';

@Component({
  selector: 'app-root',
  templateUrl: 'app.component.html',
  styleUrls: ['app.component.scss'],
  imports: [IonApp],
})
export class AppComponent implements OnInit {
  private platform = inject(Platform);
  // Injected to trigger initialization of native features (push notification permissions)
  private nativeService = inject(NativeService);
  private webViewService = inject(WebViewService);
  private sanitizer = inject(DomSanitizer);

  webViewUrl: SafeResourceUrl = this.sanitizer.bypassSecurityTrustResourceUrl(
    this.webViewService.getUrl()
  );

  async ngOnInit(): Promise<void> {
    await this.platform.ready();
    await this.webViewService.openWebView();
  }
}
