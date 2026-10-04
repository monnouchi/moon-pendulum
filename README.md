# 月の振り子 · Moon Pendulum

夜を、ひと振り。月を引いて放つと、鐘と光が音楽を奏でる。
4band の Godot 4.7.2 通常版 + GDScript 製 Web ゲーム。

- 3つの楽章、12個の光。ひと振りの大きさを学び、光の輪で折り返す
- 7つの鐘は D メジャーの五音。音・残響・ベクターアートは本作向けに制作
- マウス / タッチ / キーボード。回数制限なし、いつでも引き直せる
- 音はスタート操作後に有効。ミュートと一時停止に対応
- 第二・第三楽章では、鐘 → 仕掛け → 副振り子の物理的な連鎖が響く
- 最後に自由演奏の「余韻の庭」へ。目標なし、振り子の速さを変えて奏でられる

## 遊ぶ

公開後の URL: https://monnouchi.github.io/demo8/

月を光の輪と**反対側**へ引いて、離す。薄い緑の輪が放す場所の目安。
小さく引けば近くへ、大きく引けば遠くへ届く。

キーボード: ← → で角度調整、Space で放す、R で引き直し、M でミュート、P で一時停止、H で説明。

## GitHub Pages

1. Repository Settings → Pages → Source を **GitHub Actions** に設定する
2. Actions → **Build and publish Moon Pendulum** → Run workflow を実行する（または次の main push を待つ）

Pages のリポジトリ設定はワークフローでは変更しません。
設定前でもビルドとテスト、ダウンロードできる `moon-pendulum-web` 成果物の生成まで実行します。
設定前の deploy ステップは GitHub Pages が有効でないため失敗することがあります。

## ローカル制作

Godot **4.7.2 standard** と同じバージョンの Export Templates、Python 3 が必要。

```sh
python tools/build_assets.py
godot --headless --path game --editor --import --quit
godot --path game
```

Web 書き出しと確認:

```sh
mkdir -p docs
godot --headless --path game --export-release Web docs/index.html
python -m http.server 8000 --directory docs
```

http://localhost:8000 を開く。ファイルを直接開く方法には対応していません。
WebGL 2.0 と WebAssembly が必要です。
Compatibility renderer / single-thread export のため、COOP・COEP ヘッダー不要。
公式 Web Audio sample playback を使用し、低遅延再生に対応します。
初回読み込みには公式 Godot エンジン約38MBが含まれます。

## テスト

```sh
godot --headless --path game --script res://tests/test_game.gd
```

物理目標の到達、全楽章のクリア、方向ミスと引き不足のヒント、再判定防止、再挑戦、一時停止、説明表示、ミュートを確認。
実機の描画・タッチ・音声は各ブラウザで別途確認してください。

## 構成とライセンス

`game/` が Godot ソース。`tools/build_assets.py` がオリジナル音源と同梱フォントを再構築。
`docs/` は生成される Web 書き出しで、Git には含めず Actions artifact として配布。
GitHub Actions は公式 Godot 配布物を SHA-256 で検証してから使用。

コード・独自のアートと音源: MIT。
Noto Sans CJK の同梱サブセット: SIL Open Font License 1.1（game/assets/fonts/LICENSE.txt）。
Godot エンジン: MIT（https://godotengine.org/license/）。

[Godot Web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
