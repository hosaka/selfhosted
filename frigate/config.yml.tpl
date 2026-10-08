version: 0.14

mqtt:
  host: ${mqtt_host}
  user: "${mqtt_user}"
  password: "${mqtt_password}"

go2rtc:
  streams:
    entrance_main:
      - "rtsp://${camera_user}:${camera1_password}@${camera1_host}:554/h264Preview_01_main"
      - "ffmpeg:entrance_main#audio=opus"
    entrance_sub:
      - "rtsp://${camera_user}:${camera1_password}@${camera1_host}:554/h264Preview_01_sub"
      - "ffmpeg:entrance_sub"
    bedroom_main:
      - "rtsp://${camera_user}:${camera2_password}@${camera2_host}:554/h264Preview_01_main"
      - "ffmpeg:bedroom_main#audio=opus"

detectors:
  coral0:
    type: edgetpu
    device: pci:0
  coral1:
    type: edgetpu
    device: pci:1

ffmpeg:
  input_args: preset-rtsp-restream
  output_args:
    record: preset-record-generic-audio-copy
  # hwaccel_args: preset-vaapi

cameras:
  entrance:
    record:
      enabled: true
      events:
        retain:
          mode: active_objects
    ffmpeg:
      inputs:
        - path: "rtsp://127.0.0.1:8554/entrance_main"
          roles:
            - record
        - path: "rtsp://127.0.0.1:8554/entrance_sub"
          roles:
            - detect
    motion:
      mask:
        - 0,1,0.307,1,0.306,0.93,0.008,0.928,0.006,0.884,0.203,0,0,0
        - 0.689,1,0.777,0,1,0,1,1
  bedroom:
    motion:
      enabled: false
    detect:
      enabled: false
    record:
      enabled: false
    ffmpeg:
      inputs:
        - path: "rtsp://127.0.0.1:8554/bedroom_main"
          roles:
            - record
