# Replace Part of Video

動画の一部を AI で編集・置換するためのツール集です。Gemini API を使用して、動画のフレームに字幕を追加したり、画像を編集したりできます。

## 機能

このプロジェクトには以下の4つのシェルスクリプトが含まれています：

### 1. `separate.sh`
動画を3つの部分に分割します（編集前・編集対象・編集後）

**使用方法:**
```bash
./separate.sh -i <input.mp4> -s <start_time> -e <end_time> [-f <fps>]
```

**オプション:**
- `-i`: 入力動画ファイル
- `-s`: 開始時間（秒）
- `-e`: 終了時間（秒）
- `-f`: フレームレート（オプション）

### 2. `generate.sh`
単一のフレームに対して Gemini API を使用して画像を生成/編集します

**使用方法:**
```bash
./generate.sh -t "字幕テキスト"
```

**オプション:**
- `-t`: 追加したいテキスト/プロンプト

### 3. `parallel_gen.sh`
複数のフレームを並列処理して Gemini API で編集します

**使用方法:**
```bash
./parallel_gen.sh -t "字幕テキスト" -n <フレーム数>
```

**オプション:**
- `-t`: 追加したいテキスト/プロンプト
- `-n`: 処理するフレーム数

### 4. `concatenate.sh`
編集したフレームを動画に結合します

**使用方法:**
```bash
./concatenate.sh
```

## セットアップ

### 必要条件
- `ffmpeg` がインストールされていること
- Gemini API キー

### インストール手順

1. リポジトリをクローン:
```bash
git clone <your-repo-url>
cd replace-partofvideo
```

2. `.env` ファイルを作成:
```bash
cp .env.example .env
```

3. `.env` ファイルに Gemini API キーを設定:
```
GEMINI_API_KEY=your_actual_api_key_here
```

Gemini API キーは [Google AI Studio](https://aistudio.google.com/app/apikey) から取得できます。

## 使用例

動画の特定部分に字幕を追加する完全なワークフロー:

```bash
# 1. 動画を分割（5秒から10秒の部分を編集対象とする）
./separate.sh -i input.mp4 -s 5 -e 10

# 2. フレームを並列処理して字幕を追加
./parallel_gen.sh -t "こんにちは、世界！" -n 50

# 3. 編集したフレームを動画に結合
./concatenate.sh

# 4. 最終的な動画を結合（手動で ffmpeg を使用）
ffmpeg -i tmp/before_replace.mp4 -i output/video1.mp4 -i tmp/after_replace.mp4 \
  -filter_complex "[0:v][1:v][2:v]concat=n=3:v=1[outv]" \
  -map "[outv]" final_output.mp4
```

## クリーンアップコマンド

`runs/` ディレクトリに溜まった動画処理セッションをクリーンアップするためのコマンドが用意されています。

### 簡単なクリーンアップ（推奨）

```bash
# 現在のセッション状況を確認
./cleanup status

# 最新の3つのセッションを残して古いものを削除（確認あり）
./cleanup keep3

# クイッククリーンアップ（最新3つを残す、確認なし）
./cleanup quick

# すべてのセッションを削除（確認あり）
./cleanup all
```

### 詳細なクリーンアップオプション

```bash
# 最新のN個のセッションを残して削除
./clean.sh -k 5        # 最新5つを残す（確認あり）
./clean.sh -k 10 -y    # 最新10個を残す（確認なし）

# すべてのセッションを削除
./clean.sh -a          # 確認あり
./clean.sh -a -y       # 確認なし

# 特定のセッションを削除
./clean.sh -d runs/20251211_163422
```

詳しい使い方は `CLEANUP_GUIDE.md` を参照してください。

## ディレクトリ構造

```
replace-partofvideo/
├── separate.sh          # 動画分割スクリプト
├── generate.sh          # 単一フレーム編集スクリプト
├── parallel_gen.sh      # 並列フレーム編集スクリプト
├── concatenate.sh       # 動画結合スクリプト
├── clean.sh             # クリーンアップスクリプト
├── cleanup              # クイッククリーンアップコマンド
├── .env                 # API キー（Git管理外）
├── .env.example         # 環境変数のテンプレート
├── runs/                # セッション管理ディレクトリ（Git管理外）
│   ├── 20251211_185724/ # セッションディレクトリ（タイムスタンプ）
│   └── latest/          # 最新セッションへのシンボリックリンク
├── tmp/                 # 一時ファイル（Git管理外）
│   ├── frames/          # 元のフレーム
│   ├── before_replace.mp4
│   ├── for_replace.mp4
│   └── after_replace.mp4
└── output/              # 出力ファイル（Git管理外）
    ├── frames/          # 編集後のフレーム
    └── video1.mp4       # 編集部分の動画
```

## 注意事項

- `.env` ファイルは Git 管理から除外されています。API キーを公開しないように注意してください
- `tmp/` と `output/` ディレクトリは自動的に作成されます
- 大量のフレームを処理する場合、API の制限に注意してください

## ライセンス

MIT License

## 貢献

プルリクエストは歓迎します！
