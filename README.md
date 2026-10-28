# 月の振り子 · Moon Pendulum

月を引いて放し、振り子と鐘の音を眺める小さな庭です。五つの星座を巡る「夜の旅」も遊べます。

**[月の振り子を開く](https://monnouchi.github.io/moon-pendulum/)**

## 遊び方

タイトルをタッチ、またはEnter/Spaceで庭へ入ります。月をドラッグして放すと揺れ、金色の輪を通るたびに鐘が鳴ります。「重力」と「色と音色」で庭の雰囲気を変えられます。

「夜の旅」では輪を通って星を灯します。最初の夜は3回、ほかの夜は2回のスイングが目安です。回数を超えても続けられます。「この夜をやり直す」でその夜を最初から、「いつもの庭」で自由な庭へ戻ります。「集めた夜」から完成した星座を選べます。

| キー | 操作 |
| --- | --- |
| ← / → | 月を引く・調整する |
| Space | 月を放す |
| R | 月を中央へ戻す。旅の記録は保持 |
| M / P / H | 消音 / 一時停止 / ヘルプ |
| N | 自由な庭の色と音色を変更 |

音は最初の操作後に有効になります。画面を離れている間は鳴りません。旅の進行・ベスト記録・設定はブラウザ内に保存します。観測場所や空の描写は[架空の庭の設定](SKY_SCENES.md)です。

WebGL2とWebAssemblyに対応したブラウザが必要です。初回はエンジンの取得に時間がかかります。Web出力は静的サーバーで配信してください。

## ソースから遊ぶ

Godot **4.7.2 standard**と同版のWeb export templates、Pythonを使用します。

```sh
python3 tools/build_assets.py
godot --headless --path game --editor --import --quit
godot --path game
```

Web出力は`web-dist`フォルダを作成し、`godot --headless --path game --export-release Web ../web-dist/index.html`で生成します。`python3 -m http.server 8000 --directory web-dist`で配信できます。検証・公開の手順は[workflow](.github/workflows/web.yml)にあります。

## ライセンス

ゲームは[MIT](LICENSE)です。フォントの著作権とライセンスは[同梱全文](game/assets/fonts/LICENSE.txt)、エンジンの通知は[Web出力処理](game/addons/web_licenses/bundle.gd)を参照してください。

エディター・CLI・CIのWeb出力には`LICENSE.txt`・`FONT_LICENSE.txt`・`ENGINE_NOTICES.txt`を自動で同梱します。再配布時にもこれらを保持してください。出力の通知を検査するには`godot --headless --path game --script res://tests/test_web_distribution.gd -- ../web-dist`を使用します。
