# GarStreamTx: Raspberry Pi 5 実機配線

この `hardware/` は GarStreamTx の実機とシミュレータで共有する論理 I/F 定義です。
BCM GPIO 番号は `camera_tx.py` の既定値と一致しています。配線を変更する場合は、
この CSV と起動時の `GAR_*` 環境変数を同時に更新してください。

## 接続するモジュール

| モジュール | 接続先 | アプリから見える I/F |
|---|---|---|
| USB UVC カメラ（OV3660） | Raspberry Pi の USB ポート | `/dev/video0` (`v4l2src`) |
| KY-040 | GPIO17 / GPIO27 / GPIO22 | `periphery.GPIO` |
| ILI9341 | SPI0 CE0 + GPIO23/DC + GPIO24/RST | `/dev/spidev0.0` + GPIO |

ピンごとの接続は [connections.csv](connections.csv) が正本です。GPIO の物理ピン番号は
40-pin header のピン番号、GPIO番号は BCM 番号です。

## 配線上の注意

- KY-040 と ILI9341 は **3.3V** で接続します。GPIO に 5V を入れません。
- KY-040 の `CLK`、`DT`、`SW` が不安定な場合は、それぞれを 10kΩ で 3.3V へプルアップします。
- ILI9341 の `MISO` / `SDO` はこのアプリでは不要です。接続しなくて構いません。
- ILI9341 の `LED` はモジュールの仕様に従います。この構成では 3.3V を想定しています。
- USB カメラはハブを介さず Pi に直結して、最初の確認では唯一の UVC カメラにします。

## Raspberry Pi の事前設定

SPI0 を一度だけ有効化し、再起動します。

```bash
sudo raspi-config nonint do_spi 0
sudo reboot
```

再起動後、次を確認します。

```bash
ls -l /dev/spidev0.0 /dev/video0
v4l2-ctl --device=/dev/video0 --list-formats-ext
```

`/dev/spidev0.0` が無い場合は SPI 設定、`/dev/video0` が無い場合は USB ケーブルまたは
カメラの UVC 認識を確認します。

## アプリ設定との対応

実機起動では次を設定します。`GAR_STREAM_RX_HOST` には RX 実機の IP アドレスを入れます。

```bash
export GAR_CAMERA_DEVICE=/dev/video0
export GAR_ENC_CLK_GPIO=17
export GAR_ENC_DT_GPIO=27
export GAR_ENC_SW_GPIO=22
export GAR_LOCAL_DISPLAY=1
export GAR_LCD_DC_GPIO=23
export GAR_LCD_RST_GPIO=24
export GAR_STREAM_RX_HOST=<RXのIPアドレス>
export GAR_STREAM_RX_PORT=5600
```

カメラの実際の native mode に合わせて、必要なら `GAR_CAMERA_WIDTH`、
`GAR_CAMERA_HEIGHT`、`GAR_CAMERA_FPS`、`GAR_CAMERA_CAPS`、`GAR_CAMERA_IO_MODE` も設定します。
初期値は OV3660 の MJPEG 2048x1536@15fps を想定しています。
