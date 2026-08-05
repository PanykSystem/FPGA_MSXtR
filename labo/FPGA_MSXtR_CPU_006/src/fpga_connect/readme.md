# fpga_connect_master
## 概要
fpga_connect_master は、２つの FPGA間で、2線のシリアル通信により、情報をやり取りするモジュールである。通信相手は、fpga_connect_slave をインスタンスして接続する。

## 速度
clk は、85.90908MHz。
clk_serial は、214.7727MHz。
fpga_so_clk は、clk_serial の 1/4 で、53.693175MHz を作って出力する。

## 通信内容
|fpga_so_clk|fpga_so_data|description|
|--|--|--|
|#0|mode|00: I/O write<br>01: I/O read<br>10: Sound Send<br>11: Sound Receive|

I/O write の場合
|fpga_so_clk|方向|fpga_so_data|description|
|--|--|--|--|
|#1|out|Address[7:6]|I/O Address[7:6]|
|#2|out|Address[5:4]|I/O Address[5:4]|
|#3|out|Address[3:2]|I/O Address[3:2]|
|#4|out|Address[1:0]|I/O Address[1:0]|
|#5|out|Data[7:6]|I/O Data[7:6]|
|#6|out|Data[5:4]|I/O Data[5:4]|
|#7|out|Data[3:2]|I/O Data[3:2]|
|#8|out|Data[1:0]|I/O Data[1:0]|

I/O read の場合
|fpga_so_clk|方向|fpga_so_data|description|
|--|--|--|--|
|#1|out|Address[7:6]|I/O Address[7:6]|
|#2|out|Address[5:4]|I/O Address[5:4]|
|#3|out|Address[3:2]|I/O Address[3:2]|
|#4|out|Address[1:0]|I/O Address[1:0]|
|#5|in|read wait flag| Read data が準備できていなければ 00, 準備できたら 11。準備できるまで #5 を繰り返す。|
|#6|in|Data[7:6]|I/O Data[7:6]|
|#7|in|Data[5:4]|I/O Data[5:4]|
|#8|in|Data[3:2]|I/O Data[3:2]|
|#9|in|Data[1:0]|I/O Data[1:0]|

Sound Send の場合
|fpga_so_clk|方向|fpga_so_data|description|
|--|--|--|--|
|#1|out|L_ch[31:30]|Sound L ch. Data[31:30]|
|#2|out|L_ch[29:28]|Sound L ch. Data[29:28]|
|#3|out|L_ch[27:26]|Sound L ch. Data[27:26]|
|#4|out|L_ch[25:24]|Sound L ch. Data[25:24]|
|#5|out|L_ch[23:22]|Sound L ch. Data[23:22]|
|#6|out|L_ch[21:20]|Sound L ch. Data[21:20]|
|#7|out|L_ch[19:18]|Sound L ch. Data[19:18]|
|#8|out|L_ch[17:16]|Sound L ch. Data[17:16]|
|#9|out|L_ch[15:14]|Sound L ch. Data[15:14]|
|#10|out|L_ch[13:12]|Sound L ch. Data[13:12]|
|#11|out|L_ch[11:10]|Sound L ch. Data[11:10]|
|#12|out|L_ch[9:8]|Sound L ch. Data[9:8]|
|#13|out|L_ch[7:6]|Sound L ch. Data[7:6]|
|#14|out|L_ch[5:4]|Sound L ch. Data[5:4]|
|#15|out|L_ch[3:2]|Sound L ch. Data[3:2]|
|#16|out|L_ch[1:0]|Sound L ch. Data[1:0]|
|#17|out|R_ch[31:30]|Sound R ch. Data[31:30]|
|#18|out|R_ch[29:28]|Sound R ch. Data[29:28]|
|#19|out|R_ch[27:26]|Sound R ch. Data[27:26]|
|#20|out|R_ch[25:24]|Sound R ch. Data[25:24]|
|#21|out|R_ch[23:22]|Sound R ch. Data[23:22]|
|#22|out|R_ch[21:20]|Sound R ch. Data[21:20]|
|#23|out|R_ch[19:18]|Sound R ch. Data[19:18]|
|#24|out|R_ch[17:16]|Sound R ch. Data[17:16]|
|#25|out|R_ch[15:14]|Sound R ch. Data[15:14]|
|#26|out|R_ch[13:12]|Sound R ch. Data[13:12]|
|#27|out|R_ch[11:10]|Sound R ch. Data[11:10]|
|#28|out|R_ch[9:8]|Sound R ch. Data[9:8]|
|#29|out|R_ch[7:6]|Sound R ch. Data[7:6]|
|#30|out|R_ch[5:4]|Sound R ch. Data[5:4]|
|#31|out|R_ch[3:2]|Sound R ch. Data[3:2]|
|#32|out|R_ch[1:0]|Sound R ch. Data[1:0]|

通信中に 16clk (クロックは clk信号) 以上、I/O read の準備ができていない状態が続いたら、タイムアウトしてIDLEステートへ戻る。エラーによって通信が途絶えた場合のリカバリーである。

## プライオリティ
busアクセスと、soundアクセスが同時に来た場合は、busアクセスを優先する。soundアクセスは、busアクセスが終わるまで待たされる。

# fpga_connect_slave
## 概要
fpga_connect_slave は、２つの FPGA間で、2線のシリアル通信により、情報をやり取りするモジュールである。通信相手は、fpga_connect_master をインスタンスして接続する。

## 速度
clk は、85.90908MHz。
clk_serial は、214.7727MHz。
fpga_si_clk は、clk_serial の 1/4 くらいのクロックが入ってくるが、別 FPGA ということで非同期クロック扱いで載せ替えて使う。
