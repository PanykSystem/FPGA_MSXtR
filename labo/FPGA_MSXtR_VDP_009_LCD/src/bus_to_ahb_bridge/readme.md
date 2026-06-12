# bus_to_ahb_bridge 使い方

## 1. 何をするモジュールか
`bus_to_ahb_bridge` は、8bit の簡易バス I/F を 32bit AHB-Lite マスタ I/F に変換するブリッジです。

- 入力側バスは 2ポート構成
- `bus_address=0`: アドレスレジスタポート
- `bus_address=1`: データポート

アドレスレジスタを設定してからデータポートにアクセスすると、AHB の 1byte アクセスが発行されます。

## 2. ポートの意味

### 簡易バス側
- `bus_cs`: チップセレクト
- `bus_valid`: アクセス要求
- `bus_ready`: 受け付け可能 (`1` のとき要求可能)
- `bus_write`: 方向 (`1`: write, `0`: read)
- `bus_address`: ポート選択 (`0`: address port, `1`: data port)
- `bus_wdata[7:0]`: 書き込みデータ
- `bus_rdata[7:0]`: 読み出しデータ
- `bus_rdata_en`: 読み出しデータ有効パルス

### AHB-Lite マスタ側
- `ahb_mst_valid`, `ahb_mst_sel`: トランザクション有効
- `ahb_mst_trans`: `NONSEQ`/`IDLE` を出力
- `ahb_mst_size`: 固定で `3'b000` (byte access)
- `ahb_mst_write`: read/write
- `ahb_mst_addr[31:0]`: 32bit アドレス
- `ahb_mst_wdata[31:0]`: write データ
- `ahb_mst_ready`: スレーブ完了
- `ahb_mst_rdata[31:0]`: read データ
- `ahb_mst_resp[1:0]`: 応答 (`2'b00` のとき read 結果を返却)

## 3. 基本アクセス手順

### 3.1 アドレス設定
`bus_address=0` への write を 4回行い、下位バイトから順に 32bit アドレスを設定します。

1. 1回目: `A[7:0]`
2. 2回目: `A[15:8]`
3. 3回目: `A[23:16]`
4. 4回目: `A[31:24]`

内部の `ff_address_byte_index` が 0->1->2->3 と進み、4回で 1周します。

### 3.2 データ書き込み
`bus_address=1`, `bus_write=1` で 1byte write を発行します。

- AHB開始時のアドレスは現在の `ff_address`
- `ff_address[1:0]` に応じて `ahb_mst_wdata` の対象バイトレーンに 8bit を配置
- AHB完了 (`ahb_mst_ready=1`) 後、内部アドレスは `+1` 自動インクリメント

### 3.3 データ読み出し
`bus_address=1`, `bus_write=0` で 1byte read を発行します。

- AHB完了時、`ahb_mst_resp==2'b00` の場合のみ結果を返却
- `ff_haddr[1:0]` で対象バイトレーンを選択して `bus_rdata` に出力
- 同時に `bus_rdata_en` を 1サイクルアサート
- 完了後、内部アドレスは `+1` 自動インクリメント

## 4. レディ/ビジーの挙動
- `bus_ready = ~ff_busy`
- AHB実行中 (`ff_busy=1`) は新規の簡易バスアクセスを受け付けません
- アクセプト条件は `bus_cs && bus_valid && bus_ready`

## 5. 連続アクセスのコツ
- 最初に開始アドレスを 4byte 書き込む
- その後はデータポート (`bus_address=1`) を連続アクセスするだけで、アドレスが自動で進みます
- 1byte ストリーム読書きに向いています

## 6. 実装上の注意
- `ahb_mst_size` は byte 固定です
- `ahb_mst_resp!=2'b00` の read は `bus_rdata_en` を出しません
- 書き込み時の `ahb_mst_wdata` は対象バイト以外 0 で埋めます

## 7. 最小例 (疑似コード)

```text
# 0x12345678 をアドレスレジスタに設定
write(address_port, 0x78)
write(address_port, 0x56)
write(address_port, 0x34)
write(address_port, 0x12)

# 1byte write (0xAB) -> AHB addr=0x12345678
write(data_port, 0xAB)

# 1byte read -> AHB addr=0x12345679
read(data_port)  # bus_rdata_en を待って bus_rdata を取得
```
