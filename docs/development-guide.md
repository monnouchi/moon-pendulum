# 開発ガイド

「月の振り子」は Godot 製のゲームです。遊び方と公開 URL は [README](../README.md) を参照してください。ソースは `game/`、素材の生成処理は `tools/`、Web の生成先は `web-dist/` です。開発文書を置く `docs/` は Web 配布物に含めません。

## 開発環境と起動

Godot 4.7.2 standard と同じ版の Web export templates、Python 3 が必要です。リポジトリのルートから素材を生成し、Godot プロジェクトを読み込みます。

```sh
python3 tools/build_assets.py
godot --headless --path game --editor --import --quit
godot --path game
```

生成した音声・フォント・ビルド識別ファイルはコミット対象ではありません。

## 検証と Web 出力

ゲームと Web 描画の検査は次のコマンドで実行します。Node.js は Web 描画の検査に使用します。

```sh
godot --headless --path game --script res://tests/test_game.gd
node tools/test_web_gl_handles.cjs
mkdir -p web-dist
godot --headless --path game --export-release Web ../web-dist/index.html
godot --headless --path game --script res://tests/test_web_distribution.gd -- ../web-dist
python3 -m http.server 8000 --directory web-dist
```

最後のコマンドで静的サーバーを起動し、ブラウザで `http://localhost:8000` を開きます。WebGL2 と WebAssembly に対応したブラウザで、開始、月のドラッグと解放、音、一時停止、「夜の旅」、再読み込み後の保存状態を確認してください。Web 配布検査はゲーム本体とライセンス通知、`.nojekyll` の同梱を確認します。

## 主な構成と変更時の注意

- `game/main.tscn` と `game/scripts/main.gd`：画面とゲーム進行。
- `game/scripts/`：月・星座・空・音の描画と状態。
- `game/addons/web_licenses/`：Web 出力へのライセンス通知の同梱。
- `game/tests/`：ゲーム動作と Web 配布物の検査。
- `tools/build_assets.py`：オリジナル音声と同梱フォントなどの生成。
- `.github/workflows/web.yml`：ビルド、検査、成果物と GitHub Pages への配信。

進行や設定の保存形式を変える場合は、既存のブラウザ保存内容を読み込めることを確認してください。Web 出力の場所を変える場合は、Godot の export preset、README、workflow の出力・検査・artifact パスを一緒に更新します。`web-dist/` の生成物や検証ログ、ローカル設定はコミットしないでください。
