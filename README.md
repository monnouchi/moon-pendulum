# 月の振り子 · Moon Pendulum

夜を、ひと振り。月を引いて放すと、鐘の響きが星と水面に光を広げる。
4band の Godot 4.7.2 通常版 + GDScript 製インタラクティブ音楽作品。

## 奏でる

https://monnouchi.github.io/demo8/

「奏でる」で、自由に奏でる庭へ。
月を左右へ引いて放す。強さによって鳴る鐘と光の広がりが変わる。
左上で重力（弱 / 標準 / 強）、右下で「蒼の夜 / 灯りの夜 / 白む夜」の色と音色を変えられる。

- 三つのオリジナル音色。左右の鐘と小さな副振り子が、立体的な響きをつなぐ
- D メジャーの五音 D / E / F♯ / A / B。移動する月が旋律を生む
- 引いている間の柔らかな音、離した後の響き、伸びる光の軌跡、水面の反射
- 星座が灯ると、和音と短い旋律が夜を結ぶ。次の夜へは画面と音が穏やかにつながる
- 日本語明朝、マウス / タッチ / キーボード、ミュートと一時停止
- 音は最初の操作後に有効。タブ・アプリを離れると音を止める

キーボード: ← → 長押しで調整、Space で放す、R で引き直し、M でミュート、P で一時停止、H で説明、庭では N で夜の色と音色。

「星を灯す遊び」は任意の短い旅。金の輪で月を折り返すと、上の星座が灯る。
常時の正解位置ガイドはなく、前の折り返しと届け先を見比べて試せる。
最初の夜から、主振り子 → 鐘 → 小さな月の連鎖を体験できる。
5つの夜、11課題・15の光。途中でも庭へ寄り道し、続きへ戻れる。
クリアと途中の状態は端末内に保存。最初から遊ぶ操作は説明画面に分けている。
Webの小さな記録は localStorage と Godot の user:// に保存し、外部へ送信しない。

## GitHub Pages

1. Repository Settings → Pages → Source を **GitHub Actions** に設定する
2. Actions → **Build and publish Moon Pendulum** → Run workflow（または main push）

リポジトリの Pages 設定はワークフローで変更しない。
設定前もビルド・テスト・ダウンロード用 `moon-pendulum-web` を生成する。
成果物は1日保持。公式 Godot の配布物と公式 GitHub Actions を固定 SHA で使用。

## ローカル制作

Godot **4.7.2 standard** と同バージョンの Export Templates、Python 3。

```sh
python tools/build_assets.py
godot --headless --path game --editor --import --quit
godot --path game
```

Web:

```sh
mkdir -p docs
godot --headless --path game --export-release Web ../docs/index.html
python -m http.server 8000 --directory docs
```

http://localhost:8000 を開く。ファイルの直接起動には対応していない。
Compatibility / single-thread Web export、WebGL 2.0 + WebAssembly。
COOP・COEP ヘッダー不要。Web Audio sample playback、残響と立体感は音源に焼き込んでいる。
初回は公式 Godot エンジン約38MBを含む。

## テスト

```sh
godot --headless --path game --script res://tests/test_game.gd
```

140項目: 任意の全11課題の到達、連鎖、自由演奏の光、途中/完了後の庭への寄り道、再開、音色切替、キー調整、中断と説明、ミュート、文字、UIサイズ、JSON記録の型・範囲検証、三日月の透明な欠けと吊り姿勢、音の減衰・遷移・最終導線。
テストはプレイヤーの記録を上書きしない。描画・実機タッチ・耳での確認は別途ブラウザ QA が必要。

## 構成とライセンス

`game/` がソース。`tools/build_assets.py` がオリジナルのステレオ音源と同梱フォントを再構築。
`docs/` は生成される Web export。Git に含めず Actions artifact として配布。
公開成果物に本作・フォント・Godot/依存ライブラリのライセンスを同梱。

コード・独自アートと音源: MIT。
Noto Serif CJK 日本語明朝サブセット: SIL Open Font License 1.1（game/assets/fonts/LICENSE.txt）。
Godot: MIT（https://godotengine.org/license/）。

[Godot Web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
