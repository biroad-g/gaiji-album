{{flutter_js}}
{{flutter_build_config}}

// CanvasKit（描画エンジン）はアプリに同梱した build/web/canvaskit/ から読み込む。
// 既定の CDN（gstatic）には接続しない = オフラインでも動作する。
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
    canvasKitVariant: "full",
  },

  // Service Worker を登録して、アプリ一式を端末に保存する。
  // これが無いとオフライン時にページを開けない。
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },

  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine({
        canvasKitBaseUrl: "canvaskit/",
      });
      await appRunner.runApp();
      document.body.classList.add('ready');

      // 起動後に、まだ保存していないファイル（CanvasKit・フォントなど）を
      // まとめて端末へ保存する。初回だけオンラインで開けば、以後は
      // 機内モードでも起動できる。
      await precacheForOffline();
    } catch (e) {
      showStartupFailure();
    }
  },
});

// アプリ一式を Service Worker のキャッシュへ保存する。
async function precacheForOffline() {
  if (!('serviceWorker' in navigator)) return;
  try {
    const registration = await navigator.serviceWorker.ready;
    const worker = registration.active || registration.waiting;
    if (!worker) return;

    // 保存が終わるまで待つ（"downloadOffline" の完了を通知してもらう）
    await new Promise(function (resolve) {
      const timer = setTimeout(resolve, 20000); // 念のため上限を設ける
      navigator.serviceWorker.addEventListener('message', function onMessage(ev) {
        if (ev.data && ev.data.type === 'offlineReady') {
          clearTimeout(timer);
          navigator.serviceWorker.removeEventListener('message', onMessage);
          window.__gaijiOfflineReady = true;
          resolve();
        }
      });
      worker.postMessage('downloadOffline');
    });
  } catch (e) {
    // 保存に失敗しても、オンラインであれば通常どおり使える
  }
}

function showStartupFailure() {
  const offline = navigator.onLine === false;
  const el = document.getElementById('loading');
  if (!el) return;
  el.innerHTML =
    '<div style="max-width:330px;text-align:center;line-height:1.9;font-size:15px;color:#9B3A2E;">' +
    (offline
      ? 'アプリを起動できませんでした。<br>この端末にはまだ保存されていません。<br>インターネットにつないで、もう一度開いてください。'
      : 'アプリを起動できませんでした。<br>ページを再読み込みしてください。') +
    '</div>';
}
