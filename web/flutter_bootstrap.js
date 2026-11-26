{{flutter_js}}
{{flutter_build_config}}

// CanvasKit（描画エンジン）はアプリに同梱した build/web/canvaskit/ から読み込む。
// 既定の CDN（gstatic）には接続しない = オフラインでも動作する。
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
    canvasKitVariant: "full",
  },
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine({
        canvasKitBaseUrl: "canvaskit/",
      });
      await appRunner.runApp();
      document.body.classList.add('ready');
    } catch (e) {
      const el = document.getElementById('loading');
      if (el) {
        el.innerHTML =
          '<div style="max-width:320px;text-align:center;line-height:1.9;font-size:15px;color:#9B3A2E;">' +
          'アプリを起動できませんでした。<br>ページを再読み込みしてください。</div>';
      }
    }
  },
});
