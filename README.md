# FFmpeg-2-motioneye
Stream any stream from ffmpeg to motioneye

I had a old phone as Home assistant dashboard. But the wifi broke. So i now have a old 32bit windows tablet.
But i used the cam on the phone as a display for Motioneye i feed to home assistant. 

It appears that there was no simple way to steam the camera to motioneye.
only old win32 apps that have stupid developers that make there own http display from own knowhow instead of reading standards.

After a long time with chatgpt i have generated a python (tested under linux) that recieves a stream from FFmpeg and listens for motioneye.


## client setup FFmpeg quick howto (writen for windows users)
get your binary from ffmpeg.org or https://github.com/defisym/FFmpeg-Builds-Win32/


find your camera
`ffmpeg.exe -list_devices true -f dshow -i dummy`

For me this command results in UNICAM Front i use. 
`ffmpeg.exe -f dshow -i video="UNICAM Front" -f mjpeg http://192.168.5.253:5091/`

Now make a nice .bat file 

```
@echo off
:loop
echo Starting ffmpeg...
ffmpeg.exe -f dshow -i video="UNICAM Front" -f mjpeg http://192.168.5.253:5091/
echo ffmpeg exited, waiting 1 minute before retrying...
timeout /t 60
goto loop
```
you can setup NSSM to run the bat as service.


## Server setup

copy the python code to your server and make a systemd service 

`sudo nano /etc/systemd/system/mpeg-proxy.service`

```
[Unit]
Description=Python MJPEG Proxy
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/bin/ffmpeg-wrapper.sh
WorkingDirectory=/opt/bin
Restart=always
RestartSec=5
User=root
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
```


```
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now mpeg-proxy.service
```

## motioneye
pick a new camera select network. enter server hostname and port and your selected credentials
a camera should appear and the camera is displayed.

