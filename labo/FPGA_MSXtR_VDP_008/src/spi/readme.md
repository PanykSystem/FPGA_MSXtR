# FPGA → Pico
spi_intr = L にする。
FPGA は、Pico側がそれを認知して、それに対応するアクションを起こすまで、出したい内容を FIFO に蓄えておきます。

# Pico → FPGA
spi_cs_n = L にして、次の 1byte を送ります。
- 01h ... FPGA受信要求
- 02h ... FPGA制御要求

# FPGA受信要求
FPGAが出したいと思っている内容を受け取る要求です。 \
つまり、FPGAに送信権を与えるコマンドです。

# FPGA制御要求
FPGAに対して、Picoから制御を要求するコマンドです。

