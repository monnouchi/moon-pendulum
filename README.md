# 月の振り子 · Moon Pendulum

夜を、ひと振り。月を引いて放すと、鐘の響きが星と水面に光を広げる。
4band の Godot 4.7.2 通常版 + GDScript 製インタラクティブ音楽作品。

## 奏でる

https://monnouchi.github.io/moon-pendulum/

ソース: [monnouchi/moon-pendulum](https://github.com/monnouchi/moon-pendulum)
旧 `demo8` の公開URLは自動転送されないため、ブックマークは上記URLへ更新する。

「奏でる」で、自由に奏でる庭へ。
月を左右へ引いて放す。強さによって鳴る鐘と光の広がりが変わる。
左上で重力（弱 / 標準 / 強）、右下で「蒼の夜 / 灯りの夜 / 白む夜」の色と音色を変えられる。

- 三つのオリジナル音色。左右の鐘と小さな副振り子が、立体的な響きをつなぐ
- 庭は D メジャーの五音 D / E / F♯ / A / B。旅では主月の鐘から夜ごとに構成音が変わる
- 引いている間の柔らかな音、離した後の響き、伸びる光の軌跡、水面の反射
- 星を灯すたび高いフレーズが重なり、星座が完成すると滑らかな低音とともに曲が続く。次の夜へは画面と音が穏やかにつながる
- 日本語明朝、マウス / タッチ / キーボード、ミュートと一時停止
- 音は最初の操作後に有効。タブ・アプリを離れると音を止める

キーボード: ← → 長押しで調整、Space で放す、R で引き直し、M でミュート、P で一時停止、H で説明、庭では N で夜の色と音色。

「星を灯す遊び」は任意の短い旅。金の輪で月を折り返すと、上の星座が灯る。
常時の正解位置ガイドはなく、前の折り返しと届け先を見比べて試せる。
未達の直後は折り返しの印と差分の弧を短く強調し、連続して届かなかった時だけ小さな助言を添える。成功や再開で消え、音名や動く月の上には重ねない。
最初の夜から、主振り子 → 鐘 → 小さな月の連鎖を体験できる。
5つの夜、11課題・15の光。途中でも庭へ寄り道し、続きへ戻れる。
夜ごとに異なる拍子・旋律・音色のオリジナル曲。II/Vは小さな月が一つ届くと短く応え、二つがそろった時だけ続くフレーズが増える。
I は Dadd9 の五音、II は C と F♯ を持つ A ドリアン、III は G と F♯ が滲む Em9、IV は C・F・A の G9sus4、V は C♯ と E が重なる Dmaj9。V は最初の D に帰り、違う色の余韻を残す。
主月・引く途中の音・小月・星の層・完成低音は一つの音高表を共有する。静かな主音と五度から始まり、星が増えるにつれ第三音や7th・9thが重なる。
完成した曲は好きなだけ聴ける。次の夜を選ぶと、音と画面が1.8秒かけて消える。暗転中に0.4秒の静寂を置き、新しい夜の静かな音と画面が0.8秒で現れる。中断と説明は遷移も止め、戻ると残りの余韻から再開する。ミュートや非表示時の消音はすぐ応答する。
クリアと途中の状態、完成した曲を聴いていた夜は端末内に保存。再開しても完成時の演出は繰り返さない。最初から遊ぶ操作は説明画面に分けている。
最終Vの完成曲は再読込後も「音のつづき」で聴ける。庭へ戻ると一周を終了し、「もう一度」でIの未達状態から再演する。ベスト記録と設定は保つ。
Webの小さな記録は localStorage と Godot の user:// に保存し、外部へ送信しない。
改名後も同じブラウザの記録を引き継ぐため、保存キー `moon-pendulum.demo8.save.v1` と Godot のアプリ名・保存先を維持する。

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
COOP・COEP ヘッダー不要。Web Audio Sample 再生、残響と立体感は音源に焼き込んでいる。
音量が変わらない時は再送せず、停止済みの声の更新は省く。各声の余韻・遷移・中断からの復帰は保つ。
鐘とフレーズは既存の録音の再生速度で音高を選ぶ。起動時に倍率を計算し、演奏中の音源生成・声のプール・楽譜の発音数は増やさない。完成低音は主音を焼き込んだ4種を事前生成し、I/Vは共用する。Web Sampleのループ再開でも主音を保つ。
初回は公式 Godot エンジン約38MBを含む。
待機画面の月と細い光は実際の読み込み進捗に連動する。日本語と小さな英文タイトルを添え、タイトルの初回描画後に短く溶けるように移る。フェード開始から操作できる。動きを減らす設定に対応し、読み込みが止まった場合は再試行を表示する。

## テスト

```sh
godot --headless --path game --script res://tests/test_game.gd
```

374項目: 任意の全11課題の到達、II/Vの左右入力と弱い入力の未達、連鎖、自由演奏の光、途中/完了後の庭への寄り道、再開、音色切替、キー調整、中断と説明、ミュート、文字、UIサイズ、JSON記録の型・範囲検証、三日月の透明な欠けと吊り姿勢、音の減衰・遷移・最終導線、星の音楽層、完成低音の重複防止、継続演奏、途中/完成曲の復帰と新しい夜での層のリセット、短い未達助言の消去・連続回数・左右と狭い画面での配置、最終完了曲の直接復帰と庭を経た再演・旧保存・遷移途中の終了意図、5夜の和声整合・実プレイヤーの鐘と小月とプレビューの音高・庭への音高復帰、完成低音の固定主音とI/Vの共有、長い減衰と暗転中の静寂・中断した余韻の復帰・ミュート後の古い曲の再発防止。
テストはプレイヤーの記録を上書きしない。描画・実機タッチ・耳での確認は別途ブラウザ QA が必要。

## 構成とライセンス

`game/` がソース。`tools/build_assets.py` と `tools/build_music.py` がオリジナルのステレオ音源と同梱フォントを再構築。`game/scripts/night_harmony.gd` が5夜の構成音と楽譜、`game/scripts/night_music.gd` が音楽の進行を管理する。
`docs/` は生成される Web export。Git に含めず Actions artifact として配布。
公開成果物に本作・フォント・Godot/依存ライブラリのライセンスを同梱。

コード・独自アートと音源: MIT。
Noto Serif CJK 日本語明朝サブセット: SIL Open Font License 1.1（game/assets/fonts/LICENSE.txt）。
Godot: MIT（https://godotengine.org/license/）。

[Godot Web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
