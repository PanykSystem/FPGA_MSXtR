# 概要
FPGA MSXtR の FPGA ConfigData の更新ツールである。
指定の更新ファイルを読み取って、UART を経由して FPGA MSXtR へ転送する。

# 更新ファイル
更新ファイルは、下記のフォーマットを採用するバイナリーファイルである。
拡張子は、MFD とする。

typedef struct {
	int8_t		signature[8];
	uint32_t	check_sum;
	uint8_t		reserved[4];
} FpgaMsxConfigFileHeader;

typedef struct {
	int8_t		target_id[4];
	uint32_t	image_size;
	uint8_t		major_version;
	uint8_t		minor_version;
	uint8_t		reserved[6];
} FpgaMsxConfigDataHeader;

typedef struct {
	FpgaMsxConfigDataHeader		header;
	uint8_t						image_body[header.image_size];
} FpgaMsxConfigData;

typedef struct {
	FpgaMsxConfigFileHeader		header;
	FpgaMsxConfigData			config[];
} FpgaMsxConfigFile;

signature = "FPGAMSXC";
check_sum = ファイル内のすべての FpgaMsxConfigData を byte単位で加算した合計値。
reserved = 予約領域。00h を詰める。
target_id = "MTRC" : FPGA MSXtR board CPU Side
            "MTRV" : FPGA MSXtR board VDP Side

# UART による通信
FPGA MSX に搭載されているマイコンが通信相手である。

接続してから、"WHO ARE YOU?" の文字列を送ると "FPGA MSXtR Board" の応答を返す。
この応答を 1秒以内に返さない接続先は、ターゲットではないと認識する。

# UI
600 pixel x 400 pixel の小さなウインドウ１つで、下記のようなデザインとする。

+----------------------------------------------------+
| FPGA MSXtR Updater v1.0                         [X]|
+----------------------------------------------------+
| Target      [                   ]                  |
| Config File [                   ][Folder]          |
|                                                    |
| CPU Side    [                   ]                  |
| VDP Side    [                   ]                  |
|                                  [Write]           |
|                                           LOGO     |
|                                Copyright 2026 HRA! |
+----------------------------------------------------+

Target の右側の [ ] は、コンボボックスで、COMポートとして認識可能なシリアルポートの一覧から選べる。
選択のみで手入力はできない。

Config File の右側の [ ] は、テキスト表示枠で、手入力はできない。
[Folder] はボタンであり、クリックすると、ファイル選択ダイアログが表示される。
ファイル選択ダイアログは、拡張子 MFD の既存ファイルを選択する。
選択すると、Config File の右側の [ ] に、ファイル名を表示する。
マウスカーソルを[ ] に重ねると、ToolTip でフルパスが表示される。
選択した時点でファイルを読み込む。
ファイルサイズが 8MB を超えることは無いので、超えている場合は「正しくないファイル」と認識。
signature が一致しない場合、check_sum が一致しない場合、target_id が未知の場合も「正しくないファイル」と認識。

CPU Side, VDP Side の右側は、Config File を選択した後にバージョンが表示される。
　v{Major Version}.{Minor Version}
その領域を持たない MFDファイルだった場合は、None と表示される。
正しくないファイルだった場合は、CPU Side, VDP Side ともに Error と表示される。

[Write] はボタンであり、デフォルトではグレーアウトされてクリックできない。
Target に COMポートを選択していて、かつ 正しい MFDファイルを選択している場合にのみ、
[Write] がクリックできるようになる。
[Write] をクリックすると、書き込み処理を実施する。

# 書き込み処理
下記の順で処理を行う。

1. 選択した Target COMポートに "WHO ARE YOU?" を送り、"FPGA MSXtR Board" が返ってくることを確認する
→ 返ってこずにタイムアウトしたら、接続エラーのエラーメッセージボックスを表示して書き込み処理は中断。
2. 読み込み済みの ConfigFile の先頭から順に ConfigData を抽出し、書き込みを行っていく。
